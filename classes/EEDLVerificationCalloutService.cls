/**
 * @description Queueable callout service for EEDL AI verification.
 *              Processes one job per execution and chains itself for remaining jobs.
 *              Mirrors ApplicationVerificationCalloutService for the EEDL route.
 * @author Nitish Sinwar
 */
public class EEDLVerificationCalloutService implements Queueable, Database.AllowsCallouts {

    private static final String NAMED_CREDENTIAL_NAME = 'AI_Server';
    private static final String EEDL_ANALYZE_ENDPOINT_PATH = '/api/v1/eedl/analyze';
    private List<Id> jobIds;

    public EEDLVerificationCalloutService(Set<Id> jobIds) {
        this.jobIds = new List<Id>(jobIds);
    }

    public void execute(QueueableContext context) {
        if (jobIds.isEmpty()) return;

        Id currentJobId = jobIds.remove(0);
        AI_Server_Job__c currentJob;

        try {
            currentJob = [
                SELECT Id, Opportunity__c, Status__c
                FROM AI_Server_Job__c
                WHERE Id = :currentJobId AND Opportunity__c != null AND Status__c = 'queued'
            ];
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN, 'EEDLCalloutService: Job ' + currentJobId
                + ' not found or not dispatchable. Skipping.');
            chainNextJob();
            return;
        }

        String jsonRequestBody = JSON.serialize(new Map<String, String>{
            'record_id' => currentJob.Opportunity__c
        });
        HttpResponse response = null;
        AI_Server_Job__c jobToUpdateOnError;

        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:' + NAMED_CREDENTIAL_NAME + EEDL_ANALYZE_ENDPOINT_PATH);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            request.setTimeout(120000);
            request.setBody(jsonRequestBody);

            response = new Http().send(request);

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                ErrorLogHandler.createLog('EEDLVerificationCalloutService.execute()', 'EEDL Verification',
                    null, currentJob.Opportunity__c, jsonRequestBody, response.getBody());
            } else {
                String errorDetails = 'Server Error. Status: ' + response.getStatus()
                    + ', Body: ' + response.getBody();
                ErrorLogHandler.createLog('EEDLVerificationCalloutService.execute()', 'EEDL Verification',
                    null, currentJob.Opportunity__c, jsonRequestBody, errorDetails);
                jobToUpdateOnError = new AI_Server_Job__c(Id = currentJob.Id,
                    Status__c = 'failed', Message__c = errorDetails);
            }
        } catch (Exception e) {
            String exceptionDetails = e.getTypeName() + ': ' + e.getMessage();
            String responseBody = (response != null) ? response.getBody() : 'No response from server.';
            ErrorLogHandler.createLog('EEDLVerificationCalloutService.execute()', 'EEDL Verification',
                e, currentJob.Opportunity__c, jsonRequestBody, responseBody);
            jobToUpdateOnError = new AI_Server_Job__c(Id = currentJob.Id,
                Status__c = 'failed', Message__c = exceptionDetails);
        }

        if (jobToUpdateOnError != null) {
            try {
                update jobToUpdateOnError;
            } catch (DmlException dmlEx) {
                System.debug(LoggingLevel.ERROR, 'EEDLCalloutService: Could not mark job '
                    + jobToUpdateOnError.Id + ' as Failed: ' + dmlEx.getMessage());
            }
        }

        chainNextJob();
    }

    private void chainNextJob() {
        if (!jobIds.isEmpty()) {
            System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>(this.jobIds)));
        }
    }
}
