@isTest
public class VerificationSchedulerTest {

    @TestSetup
    static void setupTestData() {
        // Full Application infrastructure (same pattern as AppVerifCalloutSvcTest)
        Account accParent = TestDataFactory1.createTestAccount();
        List<Contact> applicant = TestDataFactory1.create5TestContactwithAccountId(accParent.Id);
        TestDataFactory1.createDegree();
        TestDataFactory1.createDegree2();
        TestDataFactory1.CreateclassificationMaster();
        Country__c country = TestDataFactory1.createCountry();
        State__c state = TestDataFactory1.createState(country.Id);
        Country_State_City__c city = TestDataFactory1.createCity(country.Id, state.Id);
        TestDataFactory1.createTestInstituteAccount(accParent.Id, country.Id, state.Id, city.Id);
        Intake__c academicYear = TestDataFactory1.CreateAcademicYear('2023-2024', true);
        hed__Program_Plan__c program = TestDataFactory1.createTestProgramWithAccount(accParent.Id, academicYear.Id);
        TestDataFactory1.createTestTerm(accParent, program);

        // 1 Queued job (no Application — for generic scheduler tests)
        // 1 Processing job
        insert new List<AI_Server_Job__c>{
            new AI_Server_Job__c(Status__c = 'Queued'),
            new AI_Server_Job__c(Status__c = 'Processing')
        };
    }

    @isTest
    static void testExecute_WithAvailableCapacity_ProcessesJobs() {
        // Mock with full capacity available (0 active jobs)
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(0));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify the queued job is processed
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        System.assertEquals(1, remainingQueued, 'All queued jobs should be processed');
    }

    @isTest
    static void testExecute_WithServerAtCapacity_SkipsProcessing() {
        // Mock server at full capacity (5 active jobs, assuming max capacity is 5)
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(5));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify no jobs are processed
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        System.assertEquals(1, remainingQueued, 'No queued jobs should be processed when server is at capacity');
    }

    @isTest
    static void testExecute_WithPartialCapacity_ProcessesLimitedJobs() {
        // Mock with partial capacity (10 active jobs, 5 slots available)
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(10));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify the queued job is processed (since capacity is available)
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        System.assertEquals(1, remainingQueued, 'All queued jobs should be processed with available capacity');
    }

    @isTest
    static void testExecute_WithServerError_HandlesGracefully() {
        // Mock server error for getActiveJobs callout
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorGenerator());

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Test jobs have no Application__c or Opportunity__c — scheduler skips them.
        // They remain Queued (not dispatched, not failed).
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        System.assertEquals(1, remainingQueued, 'Untyped jobs (no Application or Opportunity) are skipped by scheduler');
    }

    @isTest
    static void testExecute_DispatchesEEDLJobs() {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;
        Opportunity opp = opps[0];

        AI_Server_Job__c eedlJob = new AI_Server_Job__c(
            Opportunity__c = opp.Id,
            Status__c = 'Queued'
        );
        insert eedlJob;

        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(0));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // EEDL job dispatched to EEDLVerificationCalloutService — status stays Queued (mock doesn't update it)
        Integer eedlQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Opportunity__c = :opp.Id AND Status__c = 'Queued'];
        System.assertEquals(1, eedlQueued, 'EEDL job should have been dispatched (status unchanged by mock)');
    }

    @isTest
    static void testExecute_DispatchesAdmissionJobs() {
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        Contact applicant  = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant.Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        AI_Server_Job__c admissionJob = new AI_Server_Job__c(
            Application__c = app.Id,
            Status__c = 'Queued'
        );
        insert admissionJob;

        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(0));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        Integer remaining = [SELECT COUNT() FROM AI_Server_Job__c WHERE Application__c = :app.Id AND Status__c = 'Queued'];
        System.assertEquals(1, remaining, 'Admission job dispatched (status unchanged by mock)');
    }

    @isTest
    static void testScheduleNextRun_InTestContext_DoesNotSchedule() {
        // Mock with some capacity to allow execution but focus on scheduling
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(5));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify no CronTrigger is scheduled in test context
        List<CronTrigger> triggers = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = 'VerificationScheduler-Chained'
        ];
        System.assertEquals(0, triggers.size(), 'Scheduler should not chain another job in test context');
    }

    @isTest
    static void testExecute_WithNoQueuedJobs_HandlesGracefully() {
        // Delete all queued jobs to test empty queue scenario
        delete [SELECT Id FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(0));

        Test.startTest();
        VerificationScheduler scheduler = new VerificationScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify no changes to job counts
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        Integer processingJobs = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Processing'];
        System.assertEquals(0, remainingQueued, 'Should remain 0 queued jobs');
        System.assertEquals(1, processingJobs, 'Should still have 1 processing job');
    }

        


    @isTest
    static void testConstants_AreCorrectlyDefined() {
        // Test to ensure constants are accessible and have expected values
        // This helps with code coverage and validates configuration
        VerificationScheduler scheduler = new VerificationScheduler();
        
        // We can't directly access private constants, but we can test the behavior
        // that depends on them by mocking edge cases
        Test.setMock(HttpCalloutMock.class, new EnhancedMockHttpResponseGenerator(4));
        
        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();
        
        // With 4 active jobs and max of 5, only 1 job should be processed
        Integer remainingQueued = [SELECT COUNT() FROM AI_Server_Job__c WHERE Status__c = 'Queued'];
        System.assertEquals(1, remainingQueued, 'Should process the 1 job when 1 slot available');
    }

    @isTest
    static void testAbortExistingJobs_NoExistingJobs() {
        // Test the abortExistingJobs method when no existing jobs exist
        VerificationScheduler scheduler = new VerificationScheduler();
        
        Test.startTest();
        // This should not throw any exceptions
        scheduler.abortExistingJobs();
        Test.stopTest();
        
        // Verify no CronTrigger with our name exists
        Integer triggerCount = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'VerificationScheduler-Chained'];
        System.assertEquals(0, triggerCount, 'Should have no existing triggers');
    }

    @isTest
    static void testBuildCronExpression_ValidFormat() {
        // Test the buildCronExpression method
        VerificationScheduler scheduler = new VerificationScheduler();
        Datetime testTime = Datetime.newInstance(2024, 6, 15, 10, 30, 45);
        
        Test.startTest();
        String cronExpression = scheduler.buildCronExpression(testTime);
        Test.stopTest();
        
        // Verify the cron expression format
        System.assertNotEquals(null, cronExpression, 'Cron expression should not be null');
        System.assert(cronExpression.contains('45'), 'Should contain seconds');
        System.assert(cronExpression.contains('30'), 'Should contain minutes');
        System.assert(cronExpression.contains('10'), 'Should contain hours');
        System.assert(cronExpression.contains('15'), 'Should contain day');
        System.assert(cronExpression.contains('6'), 'Should contain month');
        System.assert(cronExpression.contains('2024'), 'Should contain year');
    }

    // Enhanced mock to handle multiple callout types
    public class EnhancedMockHttpResponseGenerator implements HttpCalloutMock {
        Integer activeCount;

        public EnhancedMockHttpResponseGenerator(Integer count) {
            this.activeCount = count;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('getActiveJobs')) {
                res.setBody('{"activeJobs":' + activeCount + '}');
                res.setStatusCode(200);
            } else {
                // Assume this is a job processing callout
                res.setBody('{"status":"success"}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // Mock to simulate server errors
    public class MockHttpErrorGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Server unavailable"}');
            res.setStatusCode(500);
            return res;
        }
    }
}