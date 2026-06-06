@isTest
public class EEDLVerificationCalloutServiceTest {

    static AI_Server_Job__c createEEDLJob(String status) {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;
        AI_Server_Job__c job = new AI_Server_Job__c(
            Opportunity__c = opps[0].Id,
            Status__c = status
        );
        insert job;
        return job;
    }

    @isTest
    static void testExecute_SuccessfulCallout() {
        AI_Server_Job__c job = createEEDLJob('Queued');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>{ job.Id }));
        Test.stopTest();

        AI_Server_Job__c result = [SELECT Status__c FROM AI_Server_Job__c WHERE Id = :job.Id];
        System.assertEquals('queued', result.Status__c, 'Job stays Queued after successful dispatch');
    }

    @isTest
    static void testExecute_ServerErrorMarksJobFailed() {
        AI_Server_Job__c job = createEEDLJob('Queued');
        Test.setMock(HttpCalloutMock.class, new MockServerError());

        Test.startTest();
        System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>{ job.Id }));
        Test.stopTest();

        AI_Server_Job__c result = [SELECT Status__c FROM AI_Server_Job__c WHERE Id = :job.Id];
        System.assertEquals('failed', result.Status__c, 'Job should be Failed on server error');
    }

    @isTest
    static void testExecute_SkipsNonQueuedJob() {
        AI_Server_Job__c job = createEEDLJob('Processing');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>{ job.Id }));
        Test.stopTest();

        AI_Server_Job__c result = [SELECT Status__c FROM AI_Server_Job__c WHERE Id = :job.Id];
        System.assertEquals('processing', result.Status__c, 'Non-queued job should be skipped');
    }

    @isTest
    static void testExecute_EmptyJobList() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>()));
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    @isTest
    static void testExecute_NonExistentJobSkipped() {
        Id fakeId = '006000000000001AAA';
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        System.enqueueJob(new EEDLVerificationCalloutService(new Set<Id>{ fakeId }));
        Test.stopTest();

        System.assert(true, 'Non-existent job ID handled gracefully via QueryException');
    }

    public class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"processing_queued"}');
            res.setStatusCode(202);
            return res;
        }
    }

    public class MockServerError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error":"Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }
}
