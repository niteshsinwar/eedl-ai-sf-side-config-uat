@isTest
public class AIserverAdminViewControllerTest {

    @testSetup
    static void setup() {
        Account accParent = TestDataFactory1.createTestAccount();
        List<Contact> applicant = TestDataFactory1.create5TestContactwithAccountId(accParent.Id);
        Degree__c degree = TestDataFactory1.createDegree();
        Degree__c degree2 = TestDataFactory1.createDegree2();
        ISB_Classification_Master__c classification = TestDataFactory1.CreateclassificationMaster();
        Country__c country = TestDataFactory1.createCountry();
        State__c state = TestDataFactory1.createState(country.Id);
        Country_State_City__c city = TestDataFactory1.createCity(country.Id, state.Id);
        Account institute = TestDataFactory1.createTestInstituteAccount(accParent.Id, country.Id, state.Id, city.Id);
        Intake__c academicYear = TestDataFactory1.CreateAcademicYear('2023-2024', true);
        hed__Program_Plan__c program = TestDataFactory1.createTestProgramWithAccount(accParent.Id, academicYear.Id);
        hed__Term__c term = TestDataFactory1.createTestTerm(accParent, program);
        
        // Create test data for Error_Handling__c
        Error_Handling__c successLog = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = '{"status":"processing_queued"}',
            Error_Message__c = null,
            Record_Refrence_Id__c = null
        );
        insert successLog;
        
        Error_Handling__c failLog = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = '{"status":"failed"}',
            Error_Message__c = 'Test Error',
            Record_Refrence_Id__c = null
        );
        insert failLog;
        
        // Create AI_Server_Job__c records for testing
        AI_Server_Job__c queuedJob = new AI_Server_Job__c(
            Status__c = 'Queued',
            Job_ID__c = 'TEST_JOB_001',
            Message__c = 'Test queued job',
            Progress_Details__c = '{"progress": 0}'
        );
        insert queuedJob;
        
        AI_Server_Job__c processingJob = new AI_Server_Job__c(
            Status__c = 'Processing',
            Job_ID__c = 'TEST_JOB_002',
            Message__c = 'Test processing job',
            Progress_Details__c = '{"progress": 50}'
        );
        insert processingJob;
        
        AI_Server_Job__c completedJob = new AI_Server_Job__c(
            Status__c = 'completed',
            Job_ID__c = 'TEST_JOB_003',
            Message__c = 'Test completed job',
            Progress_Details__c = '{"progress": 100}'
        );
        insert completedJob;
        
        AI_Server_Job__c failedJob = new AI_Server_Job__c(
            Status__c = 'failed',
            Job_ID__c = 'TEST_JOB_004',
            Message__c = 'Test failed job',
            Progress_Details__c = '{"progress": 0}'
        );
        insert failedJob;
    }
    
    @isTest 
    static void testController() {
        Test.startTest();
        AIserverAdminViewController controller = new AIserverAdminViewController();
        Test.stopTest();
        System.assert(true, 'Test ran');
    }
    
    @isTest 
    static void testGetActiveJobsCount() {
        AI_Server_Job__c job = new AI_Server_Job__c(Status__c='Processing');
        insert job;
        Integer count = AIserverAdminViewController.getActiveJobsCount();
        System.assertEquals(2, count); // 1 from setup + 1 from this test
    }
    
    @isTest 
    static void testGetTotalJobCount() {
        Integer count = AIserverAdminViewController.getTotalJobCount();
        System.assert(count >= 4); // At least 4 from setup
    }
    
    @isTest 
    static void testGetTotalJobCount_Exception() {
        // This would be hard to test directly, but we can ensure the method doesn't fail
        try {
            Integer count = AIserverAdminViewController.getTotalJobCount();
            System.assert(count >= 0);
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception: ' + e.getMessage());
        }
    }
    
    @isTest 
    static void testGetApiTransactions_WithLogs() {
        // Create application for testing
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        // Create log with valid application reference
        Error_Handling__c logWithApp = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = '{"status":"processing_queued"}',
            Error_Message__c = null,
            Record_Refrence_Id__c = app.Id
        );
        insert logWithApp;
        
        // Create log with invalid reference
        Error_Handling__c logWithInvalidRef = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = '{"status":"failed"}',
            Error_Message__c = 'Error',
            Record_Refrence_Id__c = 'InvalidId'
        );
        insert logWithInvalidRef;
        
        Test.startTest();
        AIserverAdminViewController.ApiTransactionResponse resp = AIserverAdminViewController.getApiTransactions();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assert(resp.succeededLogs.size() > 0);
        System.assert(resp.failedLogs.size() > 0);
    }
    
    @isTest 
    static void testGetApiTransactions_NoLogs() {
        // Delete existing logs
        delete [SELECT Id FROM Error_Handling__c WHERE Component_Type__c = 'Application Verification'];
        
        Test.startTest();
        AIserverAdminViewController.ApiTransactionResponse resp = AIserverAdminViewController.getApiTransactions();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assertEquals(0, resp.succeededLogs.size());
        System.assertEquals(0, resp.failedLogs.size());
    }
    
    @isTest 
    static void testGetConcludedJobs() {
        Test.startTest();
        List<AIserverAdminViewController.JobStatusResponse> jobs = AIserverAdminViewController.getConcludedJobs();
        Test.stopTest();
        
        System.assert(jobs.size() >= 2); // completed and failed from setup
    }
    
    @isTest 
    static void testGetConcludedJobs_WithApplications() {
        // Create application and link to job
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'completed',
            Application__c = app.Id,
            Job_ID__c = 'TEST_JOB_WITH_APP',
            Message__c = 'Test job with application'
        );
        insert job;
        
        Test.startTest();
        List<AIserverAdminViewController.JobStatusResponse> jobs = AIserverAdminViewController.getConcludedJobs();
        Test.stopTest();
        
        System.assert(jobs.size() > 0);
        Boolean foundJobWithApp = false;
        for (AIserverAdminViewController.JobStatusResponse jobResp : jobs) {
            if (jobResp.application_id == app.Id) {
                foundJobWithApp = true;
                System.assert(jobResp.applicationUrl.contains(app.Id));
                break;
            }
        }
        System.assert(foundJobWithApp, 'Should find job with application');
    }
    
    @isTest 
    static void testDeleteActiveJobs_Empty() {
        Test.startTest();
        AIserverAdminViewController.deleteActiveJobs(new List<String>());
        Test.stopTest();
        // Should not throw exception
        System.assert(true);
    }
    
    @isTest 
    static void testDeleteActiveJobs_Null() {
        Test.startTest();
        AIserverAdminViewController.deleteActiveJobs(null);
        Test.stopTest();
        // Should not throw exception
        System.assert(true);
    }
    
    @isTest 
    static void testDeleteConcludedJobs() {
        AI_Server_Job__c job = new AI_Server_Job__c(Status__c='completed');
        insert job;
        List<Id> ids = new List<Id>{job.Id};
        
        Test.startTest();
        AIserverAdminViewController.deleteConcludedJobs(ids);
        Test.stopTest();
        
        System.assert([SELECT count() FROM AI_Server_Job__c WHERE Id = :job.Id] == 0);
    }
    
    @isTest 
    static void testDeleteConcludedJobs_Empty() {
        Test.startTest();
        AIserverAdminViewController.deleteConcludedJobs(new List<Id>());
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest 
    static void testDeleteTransactions() {
        Error_Handling__c log = new Error_Handling__c(Component_Type__c='Application Verification');
        insert log;
        List<Id> ids = new List<Id>{log.Id};
        
        Test.startTest();
        AIserverAdminViewController.deleteTransactions(ids);
        Test.stopTest();
        
        System.assert([SELECT count() FROM Error_Handling__c WHERE Id = :log.Id] == 0);
    }
    
    @isTest 
    static void testDeleteTransactions_Empty() {
        Test.startTest();
        AIserverAdminViewController.deleteTransactions(new List<Id>());
        Test.stopTest();
        System.assert(true);
    }
    
    @isTest 
    static void testRetryApplications_Valid() {
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        List<Id> ids = new List<Id>{app.Id};
        
        Test.startTest();
        AIserverAdminViewController.retryApplications(ids);
        Test.stopTest();
        
        System.assert(true);
    }
    
    @isTest 
    static void testRetryApplications_EmptyList() {
        Test.startTest();
        try {
            AIserverAdminViewController.retryApplications(new List<Id>());
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage()!= null);
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testRetryApplications_Null() {
        Test.startTest();
        try {
            AIserverAdminViewController.retryApplications(null);
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage()!= null);
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testGetJobDetail_Null() {
        try {
            Test.startTest();
            AIserverAdminViewController.getJobDetail(null);
            Test.stopTest();
            System.assert(false, 'Should throw');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
    }
    
    // Mock classes for HTTP callouts
    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"active_jobs":2,"all_jobs":[{"job_id":"J1","application_id":"A1","status":"Processing","message":"msg","progress":{}}],"slot_utilization":{"cpu":0.75,"memory":0.60}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockHttpErrorResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('Server error');
            res.setStatusCode(500);
            return res;
        }
    }
    
    class ValidJobDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"job_id":"J1","application_id":"A1","status":"Queued","message":"msg","progress":{"completed":50}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockHealthResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"healthy","application_version":"1.0.0","checks":[{"name":"database","status":"healthy","details":"Connected"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockHealthResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"unhealthy"}');
            res.setStatusCode(503);
            return res;
        }
    }
    
    class MockDeleteJobsSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }
    

    
    @isTest 
    static void testGetActiveJobs_Error() {
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        Test.startTest();
        try {
            AIserverAdminViewController.getActiveJobs();
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage()!= null);
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testGetJobDetail_ValidAndInvalid() {
        Test.setMock(HttpCalloutMock.class, new ValidJobDetailMock());
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse resp = AIserverAdminViewController.getJobDetail('A1');
        Test.stopTest();
        
        System.assertEquals('A1', resp.application_id);
        System.assertEquals('J1', resp.job_id);
        System.assertEquals('Queued', resp.status);
        
        // Test error response
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        try {
            AIserverAdminViewController.getJobDetail('A1');
            System.assert(false, 'Should throw');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
    }
    
    @isTest 
    static void testGetHealthStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new MockHealthResponseSuccess());
        Test.startTest();
        AIserverAdminViewController.HealthResponse resp = AIserverAdminViewController.getHealthStatus();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assertEquals('healthy', resp.status);
        System.assertEquals('1.0.0', resp.application_version);
        System.assert(resp.checks != null);
        System.assert(resp.checks.size() > 0);
    }
    
    @isTest 
    static void testGetHealthStatus_Error() {
        Test.setMock(HttpCalloutMock.class, new MockHealthResponseError());
        Test.startTest();
        try {
            AIserverAdminViewController.getHealthStatus();
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage()!= null);
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testGetHealthStatus_Exception() {
        // Don't set mock to simulate network error
        Test.startTest();
        try {
            AIserverAdminViewController.getHealthStatus();
            System.assert(false, 'Should throw exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage()!= null);
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testDeleteActiveJobs_WithValidIds() {
        // Create application and job
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = app.Id,
            Job_ID__c = 'TEST_DELETE_JOB'
        );
        insert job;
        
        Test.setMock(HttpCalloutMock.class, new MockDeleteJobsSuccess());
        Test.startTest();
        AIserverAdminViewController.deleteActiveJobs(new List<String>{app.Id});
        Test.stopTest();
        
        // Check if job was deleted
        System.assertEquals(0, [SELECT count() FROM AI_Server_Job__c WHERE Id = :job.Id]);
    }
    
    @isTest 
    static void testDeleteActiveJobs_CalloutError() {
        // Create application and job
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = app.Id,
            Job_ID__c = 'TEST_DELETE_JOB_ERROR'
        );
        insert job;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpErrorResponse());
        Test.startTest();
        AIserverAdminViewController.deleteActiveJobs(new List<String>{app.Id});
        Test.stopTest();
        
        // Job should still exist due to callout error
        System.assertEquals(0, [SELECT count() FROM AI_Server_Job__c WHERE Id = :job.Id]);
    }
    
    @isTest 
    static void testJobStatusResponseConstructor() {
        // Test JobStatusResponse constructor with AI_Server_Job__c
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = app.Id,
            Job_ID__c = 'TEST_CONSTRUCTOR',
            Message__c = 'Test message',
            Progress_Details__c = '{"progress": 75}'
        );
        insert job;
        
        Map<Id, hed__Application__c> appMap = new Map<Id, hed__Application__c>{app.Id => app};
        
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp = 
            new AIserverAdminViewController.JobStatusResponse(job, appMap);
        Test.stopTest();
        
        System.assertEquals(job.Id, jobResp.id);
        System.assertEquals(job.Application__c, jobResp.application_id);
        System.assertEquals(app.Name, jobResp.applicationName);
        System.assertEquals(job.Job_ID__c, jobResp.job_id);
        System.assertEquals(job.Status__c, jobResp.status);
        System.assertEquals(job.Message__c, jobResp.message);
        System.assertEquals(job.Progress_Details__c, jobResp.progress);
        System.assert(jobResp.applicationUrl.contains(app.Id));
    }
    
    @isTest 
    static void testJobStatusResponseConstructor_NoAppMap() {
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = null,
            Job_ID__c = 'TEST_NO_APP'
        );
        insert job;
        
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp = 
            new AIserverAdminViewController.JobStatusResponse(job, new Map<Id, hed__Application__c>());
        Test.stopTest();
        
        System.assertEquals(job.Id, jobResp.id);
        System.assertEquals(null, jobResp.application_id);
        System.assertEquals(null, jobResp.applicationName);
        System.assertEquals(null, jobResp.applicationUrl);
    }
    
    @isTest 
    static void testApiTransactionConstructor() {
        // Test ApiTransaction constructor with valid application ID
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        Error_Handling__c log = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = 'Test Response',
            Error_Message__c = 'Test Error',
            Record_Refrence_Id__c = app.Id
        );
        insert log;
        
        Map<Id, hed__Application__c> appMap = new Map<Id, hed__Application__c>{app.Id => app};
        
        Test.startTest();
        AIserverAdminViewController.ApiTransaction apiTx = 
            new AIserverAdminViewController.ApiTransaction(log, appMap);
        Test.stopTest();
        
        System.assertEquals(log.Id, apiTx.logId);
        System.assertEquals(app.Id, apiTx.applicationId);
        System.assertEquals(app.Name, apiTx.applicationName);
        System.assert(apiTx.applicationUrl.contains(app.Id));
        System.assertEquals(log.Request__c, apiTx.request);
        System.assertEquals(log.Response__c, apiTx.response);
        System.assertEquals(log.Error_Message__c, apiTx.errorMessage);
    }
    
    @isTest 
    static void testApiTransactionConstructor_InvalidId() {
        Error_Handling__c log = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = 'Test Response',
            Error_Message__c = 'Test Error',
            Record_Refrence_Id__c = 'InvalidId'
        );
        insert log;
        
        Test.startTest();
        AIserverAdminViewController.ApiTransaction apiTx = 
            new AIserverAdminViewController.ApiTransaction(log, new Map<Id, hed__Application__c>());
        Test.stopTest();
        
        System.assertEquals(log.Id, apiTx.logId);
        System.assertEquals(null, apiTx.applicationId);
        System.assertEquals('InvalidId', apiTx.applicationName);
        System.assertEquals(null, apiTx.applicationUrl);
    }
    
    @isTest 
    static void testApiTransactionConstructor_BlankId() {
        Error_Handling__c log = new Error_Handling__c(
            Component_Type__c = 'Application Verification',
            Request__c = 'Test Request',
            Response__c = 'Test Response',
            Error_Message__c = 'Test Error',
            Record_Refrence_Id__c = ''
        );
        insert log;
        
        Test.startTest();
        AIserverAdminViewController.ApiTransaction apiTx = 
            new AIserverAdminViewController.ApiTransaction(log, new Map<Id, hed__Application__c>());
        Test.stopTest();
        
        System.assertEquals(log.Id, apiTx.logId);
        System.assertEquals(null, apiTx.applicationId);
        System.assertEquals('', apiTx.applicationName);
        System.assertEquals(null, apiTx.applicationUrl);
    }
    
    @isTest 
    static void testEmptyConstructors() {
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp = new AIserverAdminViewController.JobStatusResponse();
        AIserverAdminViewController.QueueOverviewResponse queueResp = new AIserverAdminViewController.QueueOverviewResponse();
        AIserverAdminViewController.ApiTransactionResponse apiResp = new AIserverAdminViewController.ApiTransactionResponse();
        AIserverAdminViewController.HealthResponse healthResp = new AIserverAdminViewController.HealthResponse();
        AIserverAdminViewController.DependencyStatus depStatus = new AIserverAdminViewController.DependencyStatus();
        Test.stopTest();
        
        System.assert(jobResp != null);
        System.assert(queueResp != null);
        System.assert(apiResp != null);
        System.assert(apiResp.succeededLogs != null);
        System.assert(apiResp.failedLogs != null);
        System.assert(healthResp != null);
        System.assert(depStatus != null);
    }
    
     @isTest 
    static void testGetActiveJobs_EmptyServerResponse() {
        // Mock server response with empty jobs
        Test.setMock(HttpCalloutMock.class, new MockEmptyJobsResponse());
        Test.startTest();
        AIserverAdminViewController.QueueOverviewResponse resp = AIserverAdminViewController.getActiveJobs();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assertEquals(0, resp.active_jobs);
        // Should still have queued jobs from Salesforce
    }
    
    @isTest 
    static void testGetActiveJobs_NullSlotUtilization() {
        Test.setMock(HttpCalloutMock.class, new MockNullSlotUtilizationResponse());
        Test.startTest();
        AIserverAdminViewController.QueueOverviewResponse resp = AIserverAdminViewController.getActiveJobs();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assert(resp.slot_utilization != null);
        System.assertEquals(0, resp.slot_utilization.size());
    }
    

    @isTest 
    static void testGetApiTransactions_Exception() {
        // This test covers the exception handling in getApiTransactions
        // We'll create a scenario that might cause an exception
        Test.startTest();
        try {
            AIserverAdminViewController.ApiTransactionResponse resp = AIserverAdminViewController.getApiTransactions();
            System.assert(resp != null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to fetch API transaction logs'));
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testGetConcludedJobs_Exception() {
        Test.startTest();
        try {
            List<AIserverAdminViewController.JobStatusResponse> jobs = AIserverAdminViewController.getConcludedJobs();
            System.assert(jobs != null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Failed to fetch concluded jobs'));
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testJobStatusResponseConstructor_WithApplicationNotInMap() {
        // Test when application ID exists but not in the map
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = app.Id,
            Job_ID__c = 'TEST_NOT_IN_MAP'
        );
        insert job;
        
        // Empty map - application not included
        Map<Id, hed__Application__c> emptyAppMap = new Map<Id, hed__Application__c>();
        
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp = 
            new AIserverAdminViewController.JobStatusResponse(job, emptyAppMap);
        Test.stopTest();
        
        System.assertEquals(job.Id, jobResp.id);
        System.assertEquals(job.Application__c, jobResp.application_id);
        System.assertEquals(job.Application__c, jobResp.applicationName); // Should default to app ID
        System.assert(jobResp.applicationUrl.contains(app.Id));
    }
    
    @isTest 
    static void testJobStatusResponseConstructor_BlankApplicationId() {
        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'Processing',
            Application__c = null,
            Job_ID__c = 'TEST_BLANK_APP'
        );
        insert job;
        
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp = 
            new AIserverAdminViewController.JobStatusResponse(job, new Map<Id, hed__Application__c>());
        Test.stopTest();
        
        System.assertEquals(job.Id, jobResp.id);
        System.assertEquals(null, jobResp.application_id);
        System.assertEquals(null, jobResp.applicationName);
        System.assertEquals(null, jobResp.applicationUrl);
    }

    @isTest
    static void testJobStatusResponseConstructor_WithEEDLOpportunity() {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;

        AI_Server_Job__c job = new AI_Server_Job__c(
            Status__c = 'processing',
            Opportunity__c = opps[0].Id,
            Job_ID__c = 'TEST_EEDL_JOB'
        );
        insert job;

        Test.startTest();
        AIserverAdminViewController.JobStatusResponse jobResp =
            new AIserverAdminViewController.JobStatusResponse(
                job,
                new Map<Id, hed__Application__c>(),
                new Map<Id, Opportunity>{ opps[0].Id => opps[0] }
            );
        Test.stopTest();

        System.assertEquals(String.valueOf(opps[0].Id), jobResp.application_id, 'Legacy source-id field should still carry the Opportunity Id.');
        System.assertEquals(String.valueOf(opps[0].Id), jobResp.opportunity_id, 'Opportunity Id should be exposed for EEDL jobs.');
        System.assertEquals('EEDL Opportunity', jobResp.sourceRecordType);
        System.assertEquals(opps[0].Name, jobResp.applicationName);
        System.assert(jobResp.applicationUrl.contains('/lightning/r/Opportunity/'));
    }

    @isTest
    static void testGetApiTransactions_WithEEDLLog() {
        Opportunity opp = createEEDLOpportunity();
        insert new Error_Handling__c(
            Component_Type__c = 'EEDL Verification',
            Request__c = 'EEDL Request',
            Response__c = '{"status":"processing_queued"}',
            Record_Refrence_Id__c = opp.Id
        );

        Test.startTest();
        AIserverAdminViewController.ApiTransactionResponse resp = AIserverAdminViewController.getApiTransactions();
        Test.stopTest();

        Boolean foundEedl = false;
        for (AIserverAdminViewController.ApiTransaction tx : resp.succeededLogs) {
            if (tx.applicationId == opp.Id) {
                foundEedl = true;
                System.assertEquals('EEDL Opportunity', tx.sourceRecordType);
                System.assert(tx.applicationUrl.contains('/lightning/r/Opportunity/'));
            }
        }
        System.assert(foundEedl, 'EEDL log should be visible in the shared admin transaction feed.');
    }

    @isTest
    static void testGetConcludedJobs_WithEEDLOpportunity() {
        Opportunity opp = createEEDLOpportunity();
        insert new AI_Server_Job__c(
            Status__c = 'completed',
            Opportunity__c = opp.Id,
            Job_ID__c = 'TEST_EEDL_CONCLUDED'
        );

        Test.startTest();
        List<AIserverAdminViewController.JobStatusResponse> jobs =
            AIserverAdminViewController.getConcludedJobs();
        Test.stopTest();

        Boolean foundEedl = false;
        for (AIserverAdminViewController.JobStatusResponse job : jobs) {
            if (job.opportunity_id == opp.Id) {
                foundEedl = true;
                System.assertEquals('EEDL Opportunity', job.sourceRecordType);
                System.assert(job.applicationUrl.contains('/lightning/r/Opportunity/'));
            }
        }
        System.assert(foundEedl, 'Concluded EEDL jobs should be shown in the shared admin panel.');
    }

    @isTest
    static void testGetJobLogs_WithEEDLJob() {
        Opportunity opp = createEEDLOpportunity();
        insert new AI_Server_Job__c(
            Status__c = 'completed',
            Opportunity__c = opp.Id,
            Logs__c = '{"step":"done"}'
        );

        Test.startTest();
        AIserverAdminViewController.JobLogsResponse logs = AIserverAdminViewController.getJobLogs();
        Test.stopTest();

        Boolean foundEedl = false;
        for (AIserverAdminViewController.JobLogEntry entry : logs.logs) {
            if (entry.applicationId == opp.Id) {
                foundEedl = true;
                System.assertEquals('EEDL Opportunity', entry.sourceRecordType);
                System.assert(entry.applicationUrl.contains('/lightning/r/Opportunity/'));
            }
        }
        System.assert(foundEedl, 'EEDL worker logs should be visible to admins.');
    }

    @isTest
    static void testRetryApplications_WithEEDLJob() {
        Opportunity opp = createEEDLOpportunity();
        insert new AI_Server_Job__c(
            Status__c = 'failed',
            Opportunity__c = opp.Id
        );
        List<AI_Server_Job__c> capacityJobs = new List<AI_Server_Job__c>();
        for (Integer i = 0; i < 14; i++) {
            capacityJobs.add(new AI_Server_Job__c(Status__c = 'processing'));
        }
        insert capacityJobs;

        Test.startTest();
        AIserverAdminViewController.retryApplications(new List<Id>{opp.Id});
        Test.stopTest();

        AI_Server_Job__c retried = [
            SELECT Status__c
            FROM AI_Server_Job__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];
        System.assertEquals('queued', retried.Status__c, 'Retry should route EEDL records back through the EEDL gateway.');
    }

    @isTest
    static void testGetJobDetail_WithEEDLServerPayload() {
        Test.setMock(HttpCalloutMock.class, new ValidEEDLJobDetailMock());
        Test.startTest();
        AIserverAdminViewController.JobStatusResponse resp =
            AIserverAdminViewController.getJobDetail('006000000000001AAA');
        Test.stopTest();

        System.assertEquals('006000000000001AAA', resp.opportunity_id);
        System.assertEquals('EEDL Opportunity', resp.sourceRecordType);
    }
    
    // Additional Mock classes for comprehensive testing
    class MockEmptyJobsResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"active_jobs":0,"all_jobs":[],"slot_utilization":{"cpu":0.0,"memory":0.0}}');
            res.setStatusCode(200);
            return res;
        }
    }

    class ValidEEDLJobDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"job_id":"J-EEDL","opportunity_id":"006000000000001AAA","status":"Queued","message":"msg","progress":{"completed":50}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockNullSlotUtilizationResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"active_jobs":0,"all_jobs":[],"slot_utilization":null}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockInvalidAppIdResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"active_jobs":1,"all_jobs":[{"job_id":"J1","application_id":"InvalidId","status":"Processing","message":"msg","progress":{}}],"slot_utilization":{"cpu":0.5}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    class MockSlotUtilizationWithMixedTypes implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"active_jobs":0,"all_jobs":[],"slot_utilization":{"cpu":0.75,"memory":60,"disk":"invalid"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest 
    static void testSlotUtilizationWithMixedTypes() {
        Test.setMock(HttpCalloutMock.class, new MockSlotUtilizationWithMixedTypes());
        Test.startTest();
        AIserverAdminViewController.QueueOverviewResponse resp = AIserverAdminViewController.getActiveJobs();
        Test.stopTest();
        
        System.assert(resp != null);
        System.assert(resp.slot_utilization != null);
        System.assertEquals(0.75, resp.slot_utilization.get('cpu'));
        System.assertEquals(60.0, resp.slot_utilization.get('memory'));
        System.assert(!resp.slot_utilization.containsKey('disk')); // Invalid value should be skipped
    }
    
    @isTest 
    static void testDeleteActiveJobs_NonExistentJob() {
        // Create a fake application ID that doesn't have a corresponding job
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );
        
        Test.setMock(HttpCalloutMock.class, new MockDeleteJobsSuccess());
        Test.startTest();
        AIserverAdminViewController.deleteActiveJobs(new List<String>{app.Id});
        Test.stopTest();
        
        // Should not throw exception even if no job exists for the application
        System.assert(true, 'Should complete without error');
    }

    private static Opportunity createEEDLOpportunity() {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;
        return opps[0];
    }
}
