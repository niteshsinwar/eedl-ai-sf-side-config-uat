@isTest
public class EEDLVerificationGatewayTest {

    static Opportunity createOpp() {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;
        return opps[0];
    }

    @isTest
    static void testProcessOpportunityFromLWC_Success() {
        Opportunity opp = createOpp();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        EEDLVerificationGateway.processOpportunityFromLWC(opp.Id);
        Test.stopTest();

        List<AI_Server_Job__c> jobs = [
            SELECT Id, Opportunity__c, Status__c
            FROM AI_Server_Job__c WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(1, jobs.size(), 'One AI Server Job should be created');
        System.assertEquals('queued', jobs[0].Status__c);
    }

    @isTest
    static void testProcessOpportunityFromLWC_NullId() {
        Test.startTest();
        EEDLVerificationGateway.processOpportunityFromLWC(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM AI_Server_Job__c], 'No job for null ID');
    }

    @isTest
    static void testProcessOpportunities_CreatesNewJob() {
        Opportunity opp = createOpp();
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        EEDLVerificationGateway.processOpportunities(new Set<Id>{ opp.Id });
        Test.stopTest();

        List<AI_Server_Job__c> jobs = [SELECT Id, Status__c FROM AI_Server_Job__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, jobs.size(), 'Job should be created');
        System.assertEquals('queued', jobs[0].Status__c);
    }

    @isTest
    static void testProcessOpportunities_ReusesExistingJob() {
        Opportunity opp = createOpp();
        insert new AI_Server_Job__c(Opportunity__c = opp.Id, Status__c = 'failed');
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        EEDLVerificationGateway.processOpportunities(new Set<Id>{ opp.Id });
        Test.stopTest();

        List<AI_Server_Job__c> jobs = [SELECT Id, Status__c FROM AI_Server_Job__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, jobs.size(), 'Should reuse existing job');
        System.assertEquals('queued', jobs[0].Status__c, 'Job should be reset to Queued');
    }

    @isTest
    static void testProcessOpportunities_EmptySet() {
        Test.startTest();
        EEDLVerificationGateway.processOpportunities(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM AI_Server_Job__c], 'No job for empty set');
    }

    @isTest
    static void testProcessOpportunities_AtCapacity() {
        Opportunity opp = createOpp();
        List<AI_Server_Job__c> fillerJobs = new List<AI_Server_Job__c>();
        for (Integer i = 0; i < 15; i++) {
            fillerJobs.add(new AI_Server_Job__c(Status__c = 'processing'));
        }
        insert fillerJobs;
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        EEDLVerificationGateway.processOpportunities(new Set<Id>{ opp.Id });
        Test.stopTest();

        List<AI_Server_Job__c> jobs = [SELECT Id, Status__c FROM AI_Server_Job__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, jobs.size(), 'Job created even at capacity');
        System.assertEquals('queued', jobs[0].Status__c, 'Job stays Queued at capacity');
    }

    public class MockHttpSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"processing_queued","request_id":"test-uuid"}');
            res.setStatusCode(202);
            return res;
        }
    }
}
