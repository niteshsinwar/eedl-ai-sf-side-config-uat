/**
 * @description (Refactored) A schedulable class that processes queued jobs and then 
 * re-schedules itself using a stable chaining pattern to run at a defined interval.
 * Refactored to improve test coverage while maintaining all functionality.
 * @author Nitish Sinwar
 */
public class VerificationScheduler implements Schedulable {

    private static final Integer MINUTES_BETWEEN_RUNS = 3;
    private static final Integer MAX_CONCURRENT_JOBS = 15;
    private static final String SCHEDULER_JOB_NAME = 'VerificationScheduler-Chained';

    public void execute(SchedulableContext sc) {
        
        // --- Core Job Processing Logic ---
        Integer activeJobCount = 0;
        try {
            activeJobCount = AIserverAdminViewController.getActiveJobsCount();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VerificationScheduler: Cannot check server capacity. Error: ' + e.getMessage());
            scheduleNextRun(); 
            return;
        }

        Integer availableSlots = MAX_CONCURRENT_JOBS - activeJobCount;
        System.debug('VerificationScheduler: Server capacity check. Active Jobs: ' + activeJobCount + ', Available Slots: ' + availableSlots);

        if (availableSlots > 0) {
            // Admissions jobs — Application__c populated, Opportunity__c null
            List<AI_Server_Job__c> admissionJobs = [
                SELECT Id
                FROM AI_Server_Job__c
                WHERE Status__c = 'Queued' AND Application__c != null
                ORDER BY CreatedDate ASC
                LIMIT :availableSlots
            ];

            if (!admissionJobs.isEmpty()) {
                Set<Id> ids = new Set<Id>();
                for (AI_Server_Job__c job : admissionJobs) { ids.add(job.Id); }
                System.enqueueJob(new ApplicationVerificationCalloutService(ids));
                System.debug('VerificationScheduler: Dispatched ' + ids.size() + ' admission jobs.');
            }

            // EEDL jobs — Opportunity__c populated, Application__c null
            Integer eedlSlots = availableSlots - admissionJobs.size();
            if (eedlSlots > 0) {
                List<AI_Server_Job__c> eedlJobs = [
                    SELECT Id
                    FROM AI_Server_Job__c
                    WHERE Status__c = 'Queued' AND Opportunity__c != null
                    ORDER BY CreatedDate ASC
                    LIMIT :eedlSlots
                ];
                if (!eedlJobs.isEmpty()) {
                    Set<Id> ids = new Set<Id>();
                    for (AI_Server_Job__c job : eedlJobs) { ids.add(job.Id); }
                    System.enqueueJob(new EEDLVerificationCalloutService(ids));
                    System.debug('VerificationScheduler: Dispatched ' + ids.size() + ' EEDL jobs.');
                }
            }

            if (admissionJobs.isEmpty()) {
                System.debug('VerificationScheduler: No queued jobs found to process.');
            }
        } else {
            System.debug('VerificationScheduler: Server is at full capacity. No jobs will be processed at this time.');
        }

        // --- Scheduling Logic ---
        scheduleNextRun();
    }
    
    /**
     * @description Schedules the next run. Refactored for better test coverage.
     */
    private void scheduleNextRun() {
        if (Test.isRunningTest()) return;

        // Abort existing jobs and schedule next run
        abortExistingJobs(); scheduleJob();
    }

    /**
     * @description Aborts any existing scheduled jobs with our name.
     */
    @TestVisible
    private void abortExistingJobs() {
        for (CronTrigger cronJobTrigger : [SELECT Id 
        FROM CronTrigger WHERE
         CronJobDetail.Name = :SCHEDULER_JOB_NAME]) {
            System.abortJob(cronJobTrigger.Id);
        }
    }

    /**
     * @description Creates and schedules the next job instance.
     */
    @TestVisible
    private void scheduleJob() {
        Datetime nextRunTime = System.now().addMinutes(MINUTES_BETWEEN_RUNS);
        String cronExpression = buildCronExpression(nextRunTime);
        System.schedule(SCHEDULER_JOB_NAME, cronExpression, new VerificationScheduler());
    }

    /**
     * @description Builds cron expression for the given datetime.
     */
    @TestVisible
    private String buildCronExpression(Datetime nextRunTime) {
        return String.format('{0} {1} {2} {3} {4} ? {5}', new String[]{
            String.valueOf(nextRunTime.second()),
            String.valueOf(nextRunTime.minute()),
            String.valueOf(nextRunTime.hour()),
            String.valueOf(nextRunTime.day()),
            String.valueOf(nextRunTime.month()),
            String.valueOf(nextRunTime.year())
        });
    }
}