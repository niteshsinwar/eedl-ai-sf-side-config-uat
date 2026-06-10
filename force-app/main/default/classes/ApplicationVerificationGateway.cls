/* * @description This class serves as a gateway for processing application verification jobs.
 * It handles the logic for processing applications, managing AI server jobs, and executing
 * checklist verification automation. It is designed to be called from Lightning Web Components (LWC).
 * @author Nitish Sinwar
 */
public without sharing class ApplicationVerificationGateway {
 
    private static final Integer MAX_CONCURRENT_JOBS = 15;

    @AuraEnabled
    public static void processApplicationFromLWC(Id applicationId) {
        if (applicationId != null) {
            Set<Id> appIds = new Set<Id>{ applicationId };
            processApplications(appIds);
        }
    }
    public static void processApplications(Set<Id> applicationIds) {
        if (applicationIds == null || applicationIds.isEmpty()) {
            return;
        }
        // This is the primary automation logic to be executed.
        processChecklistVerificationAutomation(applicationIds);
        
        // The rest of the original logic for handling AI Server jobs remains.
        // It can be triggered for other types of document verification.
        Map<Id, AI_Server_Job__c> existingJobsByAppId = new Map<Id, AI_Server_Job__c>();
        for (AI_Server_Job__c existingJob : [
            SELECT Id, Application__c, Status__c
            FROM AI_Server_Job__c
            WHERE Application__c IN :applicationIds
        ]) {
            existingJobsByAppId.put(existingJob.Application__c, existingJob);
        }
 
        List<AI_Server_Job__c> jobsToInsert = new List<AI_Server_Job__c>();
        List<AI_Server_Job__c> jobsToUpdate = new List<AI_Server_Job__c>();
        Set<Id> processedJobIds = new Set<Id>();
 
        for (Id appId : applicationIds) {
            if (existingJobsByAppId.containsKey(appId)) {
                AI_Server_Job__c existingJob = existingJobsByAppId.get(appId);
                existingJob.Status__c = 'Queued';
                jobsToUpdate.add(existingJob);
                processedJobIds.add(existingJob.Id);
            } else {
                AI_Server_Job__c newJob = new AI_Server_Job__c(
                    Application__c = appId,
                    Status__c = 'Queued'
                );
                jobsToInsert.add(newJob);
            }
        }
 
        if (!jobsToInsert.isEmpty()) {
            try {
                List<Database.SaveResult> insertResults = Database.insert(jobsToInsert, false);
                for (Integer i = 0; i < insertResults.size(); i++) {
                    Database.SaveResult result = insertResults[i];
                    if (result.isSuccess()) {
                        processedJobIds.add(result.getId());
                    } else {
                        System.debug('Gateway: Failed to insert job for Application: ' + jobsToInsert[i].Application__c +
                                   '. Error: ' + result.getErrors()[0].getMessage());
                    }
                }
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Gateway: Insert failed. Error: ' + e.getMessage());
                return;
            }
        }
 
        if (!jobsToUpdate.isEmpty()) {
            try {
                List<Database.SaveResult> updateResults = Database.update(jobsToUpdate, false);
                // Error handling for updates
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'Gateway: Update failed. Error: ' + e.getMessage());
                return;
            }
        }
 
        if (processedJobIds.isEmpty()) {
            System.debug('Gateway: No AI Server jobs to process.');
            return;
        }
 
        Integer activeJobCount = AIserverAdminViewController.getActiveJobsCount();
        Integer availableSlots = MAX_CONCURRENT_JOBS - activeJobCount;
 
        if (availableSlots > 0) {
            Integer jobsToSend = Math.min(availableSlots, processedJobIds.size());
            List<AI_Server_Job__c> jobsForDirectCallout = [
                SELECT Id FROM AI_Server_Job__c
                WHERE Id IN :processedJobIds
                ORDER BY CreatedDate ASC
                LIMIT :jobsToSend
            ];
            
            Set<Id> directCalloutJobIds = new Set<Id>();
            for (AI_Server_Job__c job : jobsForDirectCallout) {
                directCalloutJobIds.add(job.Id);
            }
            
            System.enqueueJob(new ApplicationVerificationCalloutService(directCalloutJobIds));
            System.debug('Gateway: Sent ' + directCalloutJobIds.size() + ' jobs directly to callout service.');
        } else {
            System.debug('Gateway: Server at capacity (' + activeJobCount + '/' + MAX_CONCURRENT_JOBS + '). Jobs queued for scheduler.');
        }
    }
 
   public static void processChecklistVerificationAutomation(Set<Id> applicationIds) {
   
    // Query application data for declaration verification
    List<hed__Application__c> applicationsToUpdate = [
        SELECT Id, Convicted_Of_Any_Crime__c, Is_legal_proceeding_not_yet_resulted__c,
        Academic_Probation__c, Charged_Under_Indian_crPC_or_IPC_Act__c
        FROM hed__Application__c
        WHERE Id IN :applicationIds
    ];

    // Query recommender details for recommender verification
    List<ISB_Recommender_Details__c> recommenderDetailsToUpdate = [
        SELECT Id, First_Name__c, Last_Name__c, Status__c, Email__c, Other_Relationship__c,
        Application__r.hed__Applicant__r.Email, Application__r.hed__Applicant__r.FirstName, Application__r.hed__Applicant__r.LastName, Application__c
        FROM ISB_Recommender_Details__c
        WHERE Application__c IN :applicationIds
    ];

    // Query recommender responses for content validation
    List<ISB_Recommender_Response__c> recommenderResponses = [
        SELECT Id, ISB_Recommender_Details__c, Answer__c
        FROM ISB_Recommender_Response__c
        WHERE ISB_Recommender_Details__c IN :recommenderDetailsToUpdate
    ];

    // Create data maps for efficient processing
    Map<Id, hed__Application__c> applicationMap = new Map<Id, hed__Application__c>();
    for (hed__Application__c app : applicationsToUpdate) {
        applicationMap.put(app.Id, app);
    }

    Map<Id, List<ISB_Recommender_Details__c>> recommendersByApplication = new Map<Id, List<ISB_Recommender_Details__c>>();
    for (ISB_Recommender_Details__c recommender : recommenderDetailsToUpdate) {
        if (!recommendersByApplication.containsKey(recommender.Application__c)) {
            recommendersByApplication.put(recommender.Application__c, new List<ISB_Recommender_Details__c>());
        }
        recommendersByApplication.get(recommender.Application__c).add(recommender);
    }

    Map<Id, List<ISB_Recommender_Response__c>> responsesByRecommender = new Map<Id, List<ISB_Recommender_Response__c>>();
    for (ISB_Recommender_Response__c response : recommenderResponses) {
        if (!responsesByRecommender.containsKey(response.ISB_Recommender_Details__c)) {
            responsesByRecommender.put(response.ISB_Recommender_Details__c, new List<ISB_Recommender_Response__c>());
        }
        responsesByRecommender.get(response.ISB_Recommender_Details__c).add(response);
    }

    Set<String> familyRelationships = new Set<String>{'brother', 'sister', 'father', 'mother', 'son', 'daughter', 'uncle', 'aunt', 'cousin', 'nephew', 'niece', 'husband', 'wife'};

    List<Application_Verification_Summary__c> summariesToUpsert = new List<Application_Verification_Summary__c>();

    // Process Declaration Analysis for each application
    for (Id applicationId : applicationIds) {
        hed__Application__c application = applicationMap.get(applicationId);
        if (application != null) {
            boolean allFieldsUnchecked =
                (application.Convicted_Of_Any_Crime__c == false) &&
                (application.Is_legal_proceeding_not_yet_resulted__c == false) &&
                (application.Academic_Probation__c == false) &&
                (application.Charged_Under_Indian_crPC_or_IPC_Act__c == false);
            
            String feedback;
            Decimal confidence;

            if (allFieldsUnchecked) {
                feedback = 'All declarations have been confirmed as negative. The applicant has attested to no criminal convictions, pending legal proceedings, academic probation, or charges under Indian law. Automated verification passed.';
                confidence = 100;
            } else {
                feedback = 'One or more declarations were answered affirmatively by the applicant. Manual review is required to assess the details of the conviction, legal proceeding, academic probation, or criminal charges.';
                confidence = 30; // Confidence in the finding
            }

            summariesToUpsert.add(new Application_Verification_Summary__c(
                Application__c = applicationId,
                Name = 'Declaration Analysis',
                Overall_Feedback__c = feedback,
                Percentage_Confidence__c = confidence
            ));
        }
    }

    // Process Recommender Details Analysis for each application
    for (Id applicationId : applicationIds) {
        List<ISB_Recommender_Details__c> recommenders = recommendersByApplication.get(applicationId);
        if (recommenders != null && !recommenders.isEmpty()) {
            List<String> validationIssues = new List<String>();
            
            for (ISB_Recommender_Details__c recommender : recommenders) {
                // Check for email match
                if (recommender.Email__c != null && recommender.Application__r.hed__Applicant__r.Email != null &&
                    recommender.Email__c.toLowerCase() == recommender.Application__r.hed__Applicant__r.Email.toLowerCase()) {
                    validationIssues.add('Recommender email matches applicant email.');
                }
                // Check for name match
                String recommenderFullName = (recommender.First_Name__c != null ? recommender.First_Name__c : '') + ' ' + (recommender.Last_Name__c != null ? recommender.Last_Name__c : '');
                String contactFullName = (recommender.Application__r.hed__Applicant__r.FirstName != null ? recommender.Application__r.hed__Applicant__r.FirstName : '') + ' ' + (recommender.Application__r.hed__Applicant__r.LastName != null ? recommender.Application__r.hed__Applicant__r.LastName : '');
                if (recommenderFullName.trim().toLowerCase() == contactFullName.trim().toLowerCase()) {
                    validationIssues.add('Recommender name matches applicant name.');
                }
                // Check for submission status
                if (recommender.Status__c != 'Submitted') {
                    validationIssues.add('Recommender status is not "Submitted".');
                }
                // Check for family relationship
                if (String.isNotBlank(recommender.Other_Relationship__c)) {
                    for (String familyRelation : familyRelationships) {
                        if (recommender.Other_Relationship__c.toLowerCase().contains(familyRelation)) {
                            validationIssues.add('Recommender relationship appears to be a family member.');
                            break;
                        }
                    }
                }
                // Check for valid response length
                List<ISB_Recommender_Response__c> responses = responsesByRecommender.get(recommender.Id);
                boolean hasValidResponse = false;
                if (responses != null) {
                    for (ISB_Recommender_Response__c response : responses) {
                        if (String.isNotBlank(response.Answer__c) && response.Answer__c.trim().split('\\s+').size() >= 4) {
                            hasValidResponse = true;
                            break;
                        }
                    }
                }
                if (!hasValidResponse) {
                    validationIssues.add('Recommender has not provided a response with sufficient content (min. 4 words).');
                }
            }
            
            String feedback;
            Decimal confidence = 100;

            if (validationIssues.isEmpty()) {
                feedback = 'All recommenders have been verified successfully based on automated checks. Recommenders have unique contact information, have submitted their responses, are not identified as family members, and have provided sufficient response content. Automated verification passed.';
            } else {
                feedback = 'One or more recommenders did not pass automated checks. Manual review is required. Issues found: ' + String.join(validationIssues, '; ');
                confidence = 30;
            }

            summariesToUpsert.add(new Application_Verification_Summary__c(
                Application__c = applicationId,
                Name = 'Recommender Details Analysis',
                Overall_Feedback__c = feedback,
                Percentage_Confidence__c = confidence
            ));
        }
    }

    // Upsert summary records
    if (!summariesToUpsert.isEmpty()) {
        // Create a map to hold existing summaries for an efficient upsert
        Map<String, Application_Verification_Summary__c> existingSummariesMap = new Map<String, Application_Verification_Summary__c>();
        for(Application_Verification_Summary__c existingSummary : [
            SELECT Id, Name, Application__c
            FROM Application_Verification_Summary__c
            WHERE Application__c IN :applicationIds
        ]){
            String uniqueKey = existingSummary.Application__c + '-' + existingSummary.Name;
            existingSummariesMap.put(uniqueKey, existingSummary);
        }

        List<Application_Verification_Summary__c> summariesToInsert = new List<Application_Verification_Summary__c>();
        List<Application_Verification_Summary__c> summariesToUpdate = new List<Application_Verification_Summary__c>();

        for(Application_Verification_Summary__c summary : summariesToUpsert){
            String key = summary.Application__c + '-' + summary.Name;
            if(existingSummariesMap.containsKey(key)){
                // Record exists, prepare for update
                summary.Id = existingSummariesMap.get(key).Id;
                summariesToUpdate.add(summary);
            } else {
                // New record, prepare for insert
                summariesToInsert.add(summary);
            }
        }

        try {
            if(!summariesToInsert.isEmpty()){
                Database.insert(summariesToInsert, false);
            }
            if(!summariesToUpdate.isEmpty()){
                Database.update(summariesToUpdate, false);
            }
             System.debug('Gateway: Processed ' + summariesToUpsert.size() + ' automated checklist verifications.');
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Gateway: Automated summary upsert failed. Error: ' + e.getMessage());
        }
    }
}
}