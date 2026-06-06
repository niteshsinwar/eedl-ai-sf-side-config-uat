/* @description This class provides the controller logic for the AI server admin view.
 * It handles API transactions, job management, and health checks for the AI server.
 * The class is designed to be used in a Lightning Web Component (LWC) context.
 * @author Nitish Sinwar
 */


public with sharing class AIserverAdminViewController {
    private static final String NAMED_CREDENTIAL_NAME = 'AI_Server';
    private static final String API_ADMIN_BASE_PATH = '/api/v1/admin';
    private static final String API_APPLICATION_BASE_PATH = '/api/v1/application';
    private static final String ENDPOINT_QUEUE_OVERVIEW = '/queue-overview';
    private static final String ENDPOINT_HEALTH = '/health';
    private static final String ENDPOINT_STATUS = '/status/';
    private static final String ENDPOINT_CLEAR_STATUS = '/processing-status/';
    private static final String ENDPOINT_ANALYZE = '/analyze';
    private static final Set<String> LOG_COMPONENT_TYPES = new Set<String>{
        'Application Verification',
        'EEDL Verification'
    };
    private static final List<String> CONCLUDED_JOB_STATUSES = new List<String>{'completed', 'failed'};
    private static final String JSON_KEY_STATUS = 'status';
    private static final String JSON_VAL_STATUS_QUEUED = 'processing_queued';

    @AuraEnabled(cacheable=true)
    public static ApiTransactionResponse getApiTransactions() {
        ApiTransactionResponse response = new ApiTransactionResponse();
        try {
            List<Error_Handling__c> logs = [
                SELECT Id, Record_Refrence_Id__c, CreatedDate, Request__c, Response__c, Error_Message__c
                FROM Error_Handling__c
                WHERE Component_Type__c IN :LOG_COMPONENT_TYPES
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
            Set<Id> appIds = new Set<Id>();
            for (Error_Handling__c log : logs) {
                if (String.isNotBlank(log.Record_Refrence_Id__c) && String.valueOf(log.Record_Refrence_Id__c).length() >= 15) {
                    try { appIds.add((Id)log.Record_Refrence_Id__c); } catch (Exception e) {}
                }
            }
            Map<Id, hed__Application__c> appMap = new Map<Id, hed__Application__c>();
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
            if (!appIds.isEmpty()) {
                appMap = new Map<Id, hed__Application__c>([SELECT Id, Name FROM hed__Application__c WHERE Id IN :appIds]);
                oppMap = new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :appIds]);
            }
            for (Error_Handling__c log : logs) {
                ApiTransaction apiTx = new ApiTransaction(log, appMap, oppMap);
                if (isSuccessfulResponse(log.Response__c)) {
                    response.succeededLogs.add(apiTx);
                } else {
                    response.failedLogs.add(apiTx);
                }
            }
            return response;
        } catch (Exception e) { throw new AuraHandledException('Failed to fetch API transaction logs: ' + e.getMessage()); }
    }
    public static Integer getActiveJobsCount() {
    // Return count from database or cached value instead of making callout
    return [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Processing'];
}
   @AuraEnabled(cacheable=true) 
    public static QueueOverviewResponse getActiveJobs() {
        try {
            Map<Id, JobStatusResponse> uniqueJobsMap = new Map<Id, JobStatusResponse>();
            Set<Id> appIdsToEnrich = new Set<Id>();
            Set<Id> oppIdsToEnrich = new Set<Id>();

            // --- Step 1: Get active jobs from the AI server ---
            HttpResponse response = makeRequest(API_APPLICATION_BASE_PATH + ENDPOINT_QUEUE_OVERVIEW, 'GET', null);
            if (response.getStatusCode() != 200) {
                throw new AuraHandledException('Server Error: ' + response.getBody());
            }
            
            QueueOverviewResponse overview = deserializeQueueOverview((Map<String, Object>) JSON.deserializeUntyped(response.getBody()));
            
            // At this point, overview.active_jobs contains the TRUE server-only count. We will NOT change it.
            
            if (overview.all_jobs != null) {
                for (JobStatusResponse serverJob : overview.all_jobs) {
                    Id sourceId = serverJob.getSourceRecordId();
                    if (sourceId != null) {
                        uniqueJobsMap.put(sourceId, serverJob);
                        if (serverJob.isEEDLJob()) {
                            oppIdsToEnrich.add(sourceId);
                        } else {
                            appIdsToEnrich.add(sourceId);
                        }
                    }
                }
            }

            // --- Step 2: Get jobs with 'Queued' status from Salesforce ---
            List<AI_Server_Job__c> queuedSalesforceJobs = [
                SELECT Id, Job_ID__c, Status__c, Message__c, LastModifiedDate, CreatedDate,
                       Application__c, Opportunity__c, Progress_Details__c
                FROM AI_Server_Job__c WHERE Status__c = 'Queued'
            ];
            
            Set<Id> queuedAppIds = new Set<Id>();
            Set<Id> queuedOppIds = new Set<Id>();
            for(AI_Server_Job__c sfJob : queuedSalesforceJobs){
                if(sfJob.Application__c != null) queuedAppIds.add(sfJob.Application__c);
                if(sfJob.Opportunity__c != null) queuedOppIds.add(sfJob.Opportunity__c);
            }
            Map<Id, hed__Application__c> tempAppMap = new Map<Id, hed__Application__c>([SELECT Id, Name FROM hed__Application__c WHERE Id IN :queuedAppIds]);
            Map<Id, Opportunity> tempOppMap = new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :queuedOppIds]);

            for (AI_Server_Job__c sfJob : queuedSalesforceJobs) {
                JobStatusResponse queuedJob = new JobStatusResponse(sfJob, tempAppMap, tempOppMap);
                Id sourceId = queuedJob.getSourceRecordId();
                if (sourceId != null && !uniqueJobsMap.containsKey(sourceId)) {
                    uniqueJobsMap.put(sourceId, queuedJob);
                    if (queuedJob.isEEDLJob()) {
                        oppIdsToEnrich.add(sourceId);
                    } else {
                        appIdsToEnrich.add(sourceId);
                    }
                }
            }

            // --- Step 3: Enrich all jobs with source-record details ---
            Map<Id, hed__Application__c> appMap = appIdsToEnrich.isEmpty()
                ? new Map<Id, hed__Application__c>()
                : new Map<Id, hed__Application__c>([SELECT Id, Name FROM hed__Application__c WHERE Id IN :appIdsToEnrich]);
            Map<Id, Opportunity> oppMap = oppIdsToEnrich.isEmpty()
                ? new Map<Id, Opportunity>()
                : new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :oppIdsToEnrich]);
            for (JobStatusResponse finalJob : uniqueJobsMap.values()) {
                finalJob.applySourceMetadata(appMap, oppMap);
            }
            
            // --- Step 4: Finalize the response object ---
            // Replace the original server-only list with our new combined & enriched list for the UI.
            overview.all_jobs = uniqueJobsMap.values();
            
            // *** THE CRITICAL FIX ***
            // We intentionally DO NOT update overview.active_jobs. It will retain the original
            // count from the server, which is what the dispatcher needs.
            
            return overview;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get active jobs: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<JobStatusResponse> getConcludedJobs() {
        // This method remains unchanged
        try {
            List<AI_Server_Job__c> jobs = [
                SELECT Id, Job_ID__c, Status__c, Message__c, LastModifiedDate, CreatedDate,
                       Application__c, Opportunity__c, Progress_Details__c
                FROM AI_Server_Job__c
                WHERE Status__c IN :CONCLUDED_JOB_STATUSES
                ORDER BY LastModifiedDate DESC
                LIMIT 100
            ];
            Set<Id> appIds = new Set<Id>();
            Set<Id> oppIds = new Set<Id>();
            for(AI_Server_Job__c job : jobs) { if(String.isNotBlank(job.Application__c)) { appIds.add(job.Application__c); } }
            for(AI_Server_Job__c job : jobs) { if(String.isNotBlank(job.Opportunity__c)) { oppIds.add(job.Opportunity__c); } }
            Map<Id, hed__Application__c> appMap = new Map<Id, hed__Application__c>();
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
            if (!appIds.isEmpty()) {
                appMap = new Map<Id, hed__Application__c>([SELECT Id, Name FROM hed__Application__c WHERE Id IN :appIds]);
            }
            if (!oppIds.isEmpty()) {
                oppMap = new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds]);
            }
            List<JobStatusResponse> results = new List<JobStatusResponse>();
            for(AI_Server_Job__c job : jobs) { results.add(new JobStatusResponse(job, appMap, oppMap)); }
            return results;
        } catch (Exception e) { throw new AuraHandledException('Failed to fetch concluded jobs: ' + e.getMessage()); }
    }
    @AuraEnabled
    public static void retryApplications(List<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            throw new AuraHandledException('No source records selected to retry.');
        }
        try {
            Set<Id> applicationRecordIds = new Set<Id>();
            Set<Id> opportunityRecordIds = new Set<Id>();
            for (AI_Server_Job__c job : [
                SELECT Application__c, Opportunity__c
                FROM AI_Server_Job__c
                WHERE Application__c IN :applicationIds OR Opportunity__c IN :applicationIds
            ]) {
                if (job.Application__c != null) applicationRecordIds.add(job.Application__c);
                if (job.Opportunity__c != null) opportunityRecordIds.add(job.Opportunity__c);
            }
            if (!applicationRecordIds.isEmpty()) {
                ApplicationVerificationGateway.processApplications(applicationRecordIds);
            }
            if (!opportunityRecordIds.isEmpty()) {
                EEDLVerificationGateway.processOpportunities(opportunityRecordIds);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to enqueue the retry job: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteActiveJobs(List<String> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return;
        }

        // List to hold all the Salesforce job records we need to delete.
        List<AI_Server_Job__c> jobsToDelete = new List<AI_Server_Job__c>();

        // For efficiency, get all potential jobs in a single query and map them by source record ID.
        Map<String, AI_Server_Job__c> jobsBySourceId = new Map<String, AI_Server_Job__c>();
        for(AI_Server_Job__c job : [
            SELECT Id, Application__c, Opportunity__c FROM AI_Server_Job__c
            WHERE (Application__c IN :applicationIds OR Opportunity__c IN :applicationIds)
              AND Status__c NOT IN :CONCLUDED_JOB_STATUSES
        ]) {
            String sourceId = job.Application__c != null ? String.valueOf(job.Application__c) : String.valueOf(job.Opportunity__c);
            jobsBySourceId.put(sourceId, job);
        }

        // Loop through each selected Application ID to make the required callout to the server.
        for (String appId : applicationIds) {
            try {
                // Make one callout per job to clear it from the server's queue.
                makeRequest(API_ADMIN_BASE_PATH + ENDPOINT_CLEAR_STATUS + appId, 'DELETE', null);

                // If the callout was successful, find the corresponding Salesforce job
                // from our map and add it to our list for deletion.
                if (jobsBySourceId.containsKey(appId)) {
                    jobsToDelete.add(jobsBySourceId.get(appId));
                }

            } catch (Exception e) {
                // If one callout fails, log it and continue to the next one.
                System.debug('Failed to process deletion callout for active job ' + appId + ': ' + e.getMessage());
            }
        }

        // AFTER the loop, perform one single, bulk DML operation on all collected jobs.
        if (!jobsToDelete.isEmpty()) {
            try {
                delete jobsToDelete;
            } catch(DmlException e) {
                // If the final delete fails, throw an error back to the LWC.
                throw new AuraHandledException('Failed to delete job records in Salesforce: ' + e.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void deleteConcludedJobs(List<Id> jobIds) {
        delete [SELECT Id FROM AI_Server_Job__c WHERE Id IN :jobIds];
    }

    @AuraEnabled
    public static void deleteTransactions(List<Id> logIds) {
        delete [SELECT Id FROM Error_Handling__c WHERE Id IN :logIds];
    }

    @AuraEnabled(cacheable=true)
    public static HealthResponse getHealthStatus() {
        try {
            HttpResponse response = makeRequest(API_ADMIN_BASE_PATH + ENDPOINT_HEALTH, 'GET', null);
            if (response.getStatusCode() == 200) {
                return (HealthResponse) JSON.deserialize(response.getBody(), HealthResponse.class);
            }
            throw new AuraHandledException('Server responded with status ' + response.getStatusCode() + ': ' + response.getBody());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Health Check Callout Error: ' + e.getMessage());
            throw new AuraHandledException('Failed to get health status: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Integer getTotalJobCount() {
        try {
            return [SELECT count() FROM AI_Server_Job__c];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to count AI Server Job records: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static JobLogsResponse getJobLogs() {
        try {
            List<AI_Server_Job__c> jobs = [
                SELECT Id, Application__c, Opportunity__c, Logs__c, Status__c, CreatedDate, LastModifiedDate
                FROM AI_Server_Job__c
                ORDER BY LastModifiedDate DESC
                LIMIT 500
            ];

            Set<Id> appIds = new Set<Id>();
            Set<Id> oppIds = new Set<Id>();
            for (AI_Server_Job__c job : jobs) {
                if (String.isNotBlank(job.Application__c)) {
                    appIds.add(job.Application__c);
                }
                if (String.isNotBlank(job.Opportunity__c)) {
                    oppIds.add(job.Opportunity__c);
                }
            }

            Map<Id, hed__Application__c> appMap = new Map<Id, hed__Application__c>();
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
            if (!appIds.isEmpty()) {
                appMap = new Map<Id, hed__Application__c>([SELECT Id, Name FROM hed__Application__c WHERE Id IN :appIds]);
            }
            if (!oppIds.isEmpty()) {
                oppMap = new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds]);
            }

            JobLogsResponse response = new JobLogsResponse();
            for (AI_Server_Job__c job : jobs) {
                // Skip records with null or empty Logs__c (can't filter in SOQL for Long Text Area)
                if (String.isBlank(job.Logs__c)) {
                    continue;
                }

                JobLogEntry entry = new JobLogEntry();
                entry.jobId = job.Id;
                entry.applicationId = job.Application__c != null
                    ? String.valueOf(job.Application__c)
                    : (job.Opportunity__c != null ? String.valueOf(job.Opportunity__c) : null);
                entry.logsJson = job.Logs__c;
                entry.status = job.Status__c;
                entry.createdDate = job.CreatedDate;
                entry.lastModifiedDate = job.LastModifiedDate;
                entry.sourceRecordType = job.Opportunity__c != null
                    ? 'EEDL Opportunity'
                    : (job.Application__c != null ? 'Admissions Application' : 'Unknown');

                if (String.isNotBlank(job.Application__c)) {
                    entry.applicationUrl = '/lightning/r/hed__Application__c/' + job.Application__c + '/view';
                    if (appMap.containsKey(job.Application__c)) {
                        entry.applicationName = appMap.get(job.Application__c).Name;
                    } else {
                        entry.applicationName = job.Application__c;
                    }
                } else if (String.isNotBlank(job.Opportunity__c)) {
                    entry.applicationUrl = '/lightning/r/Opportunity/' + job.Opportunity__c + '/view';
                    if (oppMap.containsKey(job.Opportunity__c)) {
                        entry.applicationName = oppMap.get(job.Opportunity__c).Name;
                    } else {
                        entry.applicationName = job.Opportunity__c;
                    }
                }
                response.logs.add(entry);
            }
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch job logs: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static JobStatusResponse getJobDetail(String applicationId) {
        try {
            HttpResponse response = makeRequest(API_APPLICATION_BASE_PATH + ENDPOINT_STATUS + applicationId, 'GET', null);
            if (response.getStatusCode() == 200) {
                return parseJobStatusFromMap((Map<String, Object>) JSON.deserializeUntyped(response.getBody()));
            }
            throw new AuraHandledException('Server responded with status ' + response.getStatusCode() + ': ' + response.getBody());
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get job detail: ' + e.getMessage());
        }
    }

    private static Boolean isSuccessfulResponse(String responseBody) {
        if (String.isBlank(responseBody)) {
            return false;
        }
        try {
            Map<String, Object> parsedResponse = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
            if (parsedResponse.containsKey(JSON_KEY_STATUS)) {
                return JSON_VAL_STATUS_QUEUED.equals(parsedResponse.get(JSON_KEY_STATUS));
            }
        } catch (System.JSONException e) {
            return false;
        }
        return false;
    }

    private static HttpResponse makeRequest(String path, String method, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL_NAME + path);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);
        if (body != null) req.setBody(body);
        return new Http().send(req);
    }

    private static JobStatusResponse parseJobStatusFromMap(Map<String, Object> jobMap) {
        JobStatusResponse job = new JobStatusResponse();
        job.job_id = (String) jobMap.get('job_id');
        job.application_id = (String) jobMap.get('application_id');
        job.opportunity_id = (String) jobMap.get('opportunity_id');
        job.sourceRecordType = String.isNotBlank(job.opportunity_id) ? 'EEDL Opportunity' : 'Admissions Application';
        job.status = (String) jobMap.get('status');
        job.message = (String) jobMap.get('message');
        job.progress = JSON.serialize(jobMap.get('progress'));
        return job;
    }

    private static QueueOverviewResponse deserializeQueueOverview(Map<String, Object> untypedResponse) {
        QueueOverviewResponse overview = new QueueOverviewResponse();
        overview.active_jobs = (Integer) untypedResponse.get('active_jobs');
        overview.all_jobs = new List<JobStatusResponse>();
        List<Object> jobsList = (List<Object>) untypedResponse.get('all_jobs');
        if (jobsList != null) {
            for (Object jobObj: jobsList) {
                overview.all_jobs.add(parseJobStatusFromMap((Map<String, Object>) jobObj));
            }
        }
        Map<String, Double> typedSlotUtilization = new Map<String, Double>();
        if (untypedResponse.get('slot_utilization') != null) {
            Map<String, Object> untypedSlots = (Map<String, Object>) untypedResponse.get('slot_utilization');
            for (String key: untypedSlots.keySet()) {
                Object val = untypedSlots.get(key);
                if (val instanceof Decimal || val instanceof Double || val instanceof Integer) {
                    typedSlotUtilization.put(key, Decimal.valueOf(String.valueOf(val)).doubleValue());
                }
            }
        }
        overview.slot_utilization = typedSlotUtilization;
        return overview;
    }

    public class HealthResponse { 
        @AuraEnabled public String status; 
        @AuraEnabled public String application_version; 
        @AuraEnabled public List<DependencyStatus> checks;
    }
    public class DependencyStatus { 
        @AuraEnabled public String name; 
        @AuraEnabled public String status; 
        @AuraEnabled public String details;
    }
    public class JobStatusResponse {
        @AuraEnabled public String job_id, application_id, opportunity_id, status, message, progress, applicationName, applicationUrl, sourceRecordType;
        @AuraEnabled public Datetime created_at, last_updated_at;
        @AuraEnabled public String id; // Added for Salesforce Id
        public JobStatusResponse() {}
        public JobStatusResponse(AI_Server_Job__c r, Map<Id, hed__Application__c> appMap) {
            this(r, appMap, new Map<Id, Opportunity>());
        }
        public JobStatusResponse(AI_Server_Job__c r, Map<Id, hed__Application__c> appMap, Map<Id, Opportunity> oppMap) {
            this.id = r.Id;
            this.application_id = r.Application__c != null
                ? String.valueOf(r.Application__c)
                : (r.Opportunity__c != null ? String.valueOf(r.Opportunity__c) : null);
            this.opportunity_id = r.Opportunity__c != null ? String.valueOf(r.Opportunity__c) : null;
            this.sourceRecordType = r.Opportunity__c != null
                ? 'EEDL Opportunity'
                : (r.Application__c != null ? 'Admissions Application' : 'Unknown');
            applySourceMetadata(appMap, oppMap);
            this.job_id = r.Job_ID__c; 
            this.status = r.Status__c; 
            this.message = r.Message__c; 
            this.created_at = r.CreatedDate; 
            this.last_updated_at = r.LastModifiedDate; 
            this.progress = r.Progress_Details__c;
        }
        public Boolean isEEDLJob() {
            return String.isNotBlank(this.opportunity_id);
        }
        public Id getSourceRecordId() {
            String sourceId = isEEDLJob() ? this.opportunity_id : this.application_id;
            if (String.isBlank(sourceId)) return null;
            try {
                return (Id)sourceId;
            } catch (Exception e) {
                return null;
            }
        }
        public void applySourceMetadata(Map<Id, hed__Application__c> appMap, Map<Id, Opportunity> oppMap) {
            Id sourceId = getSourceRecordId();
            if (sourceId == null) return;

            if (isEEDLJob()) {
                this.sourceRecordType = 'EEDL Opportunity';
                this.applicationName = oppMap.containsKey(sourceId) ? oppMap.get(sourceId).Name : String.valueOf(sourceId);
                this.applicationUrl = '/lightning/r/Opportunity/' + sourceId + '/view';
            } else {
                this.sourceRecordType = 'Admissions Application';
                this.applicationName = appMap.containsKey(sourceId) ? appMap.get(sourceId).Name : String.valueOf(sourceId);
                this.applicationUrl = '/lightning/r/hed__Application__c/' + sourceId + '/view';
            }
        }
    }
    public class QueueOverviewResponse { 
        @AuraEnabled public Integer active_jobs; 
        @AuraEnabled public Map<String, Double> slot_utilization; 
        @AuraEnabled public List<JobStatusResponse> all_jobs; 
    }
    public class ApiTransactionResponse {
        @AuraEnabled public List<ApiTransaction> succeededLogs = new List<ApiTransaction>();
        @AuraEnabled public List<ApiTransaction> failedLogs = new List<ApiTransaction>();
    }
    public class ApiTransaction {
        @AuraEnabled public Id logId, applicationId;
        @AuraEnabled public String applicationName, applicationUrl, sourceRecordType, request, response, errorMessage;
        @AuraEnabled public Datetime createdAt;
        public ApiTransaction(Error_Handling__c l, Map<Id, hed__Application__c> appMap){
            this(l, appMap, new Map<Id, Opportunity>());
        }
        public ApiTransaction(Error_Handling__c l, Map<Id, hed__Application__c> appMap, Map<Id, Opportunity> oppMap){
            this.logId = l.Id;
            this.createdAt = l.CreatedDate;
            this.request = l.Request__c;
            this.response = l.Response__c;
            this.errorMessage = l.Error_Message__c;
            this.applicationName = l.Record_Refrence_Id__c;
            if (String.isNotBlank(l.Record_Refrence_Id__c) && String.valueOf(l.Record_Refrence_Id__c).length() >= 15) {
                try {
                    Id appId = (Id)l.Record_Refrence_Id__c;
                    this.applicationId = appId;
                    if (appMap.containsKey(appId)) {
                        this.applicationName = appMap.get(appId).Name;
                        this.applicationUrl = '/lightning/r/hed__Application__c/' + appId + '/view';
                        this.sourceRecordType = 'Admissions Application';
                    } else if (oppMap.containsKey(appId)) {
                        this.applicationName = oppMap.get(appId).Name;
                        this.applicationUrl = '/lightning/r/Opportunity/' + appId + '/view';
                        this.sourceRecordType = 'EEDL Opportunity';
                    }
                } catch (Exception e) {
                    this.applicationUrl = null;
                }
            }
        }
    }

    public class JobLogsResponse {
        @AuraEnabled public List<JobLogEntry> logs = new List<JobLogEntry>();
    }

    public class JobLogEntry {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String applicationId;
        @AuraEnabled public String applicationName;
        @AuraEnabled public String applicationUrl;
        @AuraEnabled public String sourceRecordType;
        @AuraEnabled public String logsJson;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
    }
}
