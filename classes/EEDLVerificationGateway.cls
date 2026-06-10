/**
 * @description Gateway for EEDL AI document verification.
 *              Creates AI_Server_Job__c records for Opportunities and dispatches
 *              EEDLVerificationCalloutService when server capacity is available.
 *              Called from CEE_OpportunityTriggerHandler on StageName → "Applicant".
 * @author Nitish Sinwar
 */
public without sharing class EEDLVerificationGateway {

    private static final Integer MAX_CONCURRENT_JOBS = 15;

    @AuraEnabled
    public static void processOpportunityFromLWC(Id opportunityId) {
        if (opportunityId != null) {
            processOpportunities(new Set<Id>{ opportunityId });
        }
    }

    public static void processOpportunities(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) return;

        Map<Id, AI_Server_Job__c> existingJobsByOppId = new Map<Id, AI_Server_Job__c>();
        for (AI_Server_Job__c job : [
            SELECT Id, Opportunity__c, Status__c
            FROM AI_Server_Job__c
            WHERE Opportunity__c IN :opportunityIds
        ]) {
            existingJobsByOppId.put(job.Opportunity__c, job);
        }

        List<AI_Server_Job__c> jobsToInsert = new List<AI_Server_Job__c>();
        List<AI_Server_Job__c> jobsToUpdate = new List<AI_Server_Job__c>();
        Set<Id> processedJobIds = new Set<Id>();

        for (Id oppId : opportunityIds) {
            if (existingJobsByOppId.containsKey(oppId)) {
                AI_Server_Job__c existing = existingJobsByOppId.get(oppId);
                existing.Status__c = 'queued';
                jobsToUpdate.add(existing);
                processedJobIds.add(existing.Id);
            } else {
                jobsToInsert.add(new AI_Server_Job__c(
                    Opportunity__c = oppId,
                    Status__c = 'queued'
                ));
            }
        }

        if (!jobsToInsert.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(jobsToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    processedJobIds.add(results[i].getId());
                } else {
                    System.debug(LoggingLevel.ERROR, 'EEDLVerificationGateway: Insert failed for Opp '
                        + jobsToInsert[i].Opportunity__c + ': ' + results[i].getErrors()[0].getMessage());
                }
            }
        }

        if (!jobsToUpdate.isEmpty()) {
            Database.update(jobsToUpdate, false);
        }

        if (processedJobIds.isEmpty()) return;

        Integer activeJobCount = AIserverAdminViewController.getActiveJobsCount();
        Integer availableSlots = MAX_CONCURRENT_JOBS - activeJobCount;

        if (availableSlots > 0) {
            Set<Id> directCalloutJobIds = new Set<Id>();
            Integer count = 0;
            for (Id jobId : processedJobIds) {
                if (count >= availableSlots) break;
                directCalloutJobIds.add(jobId);
                count++;
            }
            System.enqueueJob(new EEDLVerificationCalloutService(directCalloutJobIds));
        } else {
            System.debug('EEDLVerificationGateway: Server at capacity (' + activeJobCount
                + '/' + MAX_CONCURRENT_JOBS + '). EEDL jobs queued for scheduler.');
        }
    }
}