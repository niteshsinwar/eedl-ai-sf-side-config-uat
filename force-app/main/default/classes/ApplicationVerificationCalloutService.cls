/**
 * @description CALLOUT SERVICE (Updated)
 * Makes a background callout for ONE job, then re-enqueues itself with the remaining jobs.
 * This version includes robust error handling and reinstates the ErrorLogHandler.
 * @author Nitish Sinwar
 * @date June 19, 2025
 */
public class ApplicationVerificationCalloutService implements Queueable, Database.AllowsCallouts {

    private static final String NAMED_CREDENTIAL_NAME = 'AI_Server';
    private static final String ANALYZE_ENDPOINT_PATH = '/api/v1/application/analyze';
    private List<Id> jobIds;

    public ApplicationVerificationCalloutService(Set<Id> jobIds) {
        this.jobIds = new List<Id>(jobIds);
    }

    public void execute(QueueableContext context) {
        if (jobIds.isEmpty()) {
            System.debug('Callout Service: Batch complete.');
            return;
        }

        Id currentJobId = jobIds.remove(0);
        AI_Server_Job__c currentJob;
        
        try {
            currentJob = [
                SELECT Id, Application__c, Status__c 
                FROM AI_Server_Job__c 
                WHERE Id = :currentJobId AND Status__c = 'Queued'
            ];
        } catch (QueryException e) {
            System.debug(LoggingLevel.WARN, 'Callout Service: Job ' + currentJobId + ' not found or not in a dispatchable state. Skipping.');
            chainNextJob();
            return;
        }

        AI_Server_Job__c jobToUpdateOnError;
        String jsonRequestBody = JSON.serialize(new Map<String, String>{
            'record_id' => currentJob.Application__c,
            'job_id' => currentJob.Id
        });
        HttpResponse response = null;

        try {
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:' + NAMED_CREDENTIAL_NAME + ANALYZE_ENDPOINT_PATH);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json;charset=UTF-8');
            request.setTimeout(120000); // 2 minute timeout
            request.setBody(jsonRequestBody);

            response = new Http().send(request);

            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                // SUCCESS: Log the successful transaction.
                ErrorLogHandler.createLog('ApplicationVerificationCalloutService.execute()', 'Application Verification', null, currentJob.Application__c, jsonRequestBody, response.getBody());
                System.debug('Callout Service: Successfully sent job ' + currentJob.Id + '.');
            } else {
                // ERROR: Server returned an error. Log it.
                String errorDetails = 'Server Error. Status: ' + response.getStatus() + ', Body: ' + response.getBody();
                ErrorLogHandler.createLog('ApplicationVerificationCalloutService.execute()', 'Application Verification', null, currentJob.Application__c, jsonRequestBody, errorDetails);
                jobToUpdateOnError = new AI_Server_Job__c(Id = currentJob.Id, Status__c = 'Failed', Message__c = errorDetails);
            }
        } catch (Exception e) {
            // EXCEPTION: A system/network error occurred. Log it.
            String exceptionDetails = e.getTypeName() + ': ' + e.getMessage();
            String responseBody = (response != null) ? response.getBody() : 'No response from server.';
            ErrorLogHandler.createLog('ApplicationVerificationCalloutService.execute()', 'Application Verification', e, currentJob.Application__c, jsonRequestBody, responseBody);
            jobToUpdateOnError = new AI_Server_Job__c(Id = currentJob.Id, Status__c = 'Failed', Message__c = exceptionDetails);
        }

        if (jobToUpdateOnError != null) {
            try {
                update jobToUpdateOnError;
            } catch (DmlException dmlEx) {
                System.debug(LoggingLevel.ERROR, 'Callout Service: Could not mark job ' + jobToUpdateOnError.Id + ' as Failed. Error: ' + dmlEx.getMessage());
            }
        }

        chainNextJob();
    }
    
    private void chainNextJob() {
        if (!jobIds.isEmpty()) {
            System.enqueueJob(new ApplicationVerificationCalloutService(new Set<Id>(this.jobIds)));
        }
    }
}