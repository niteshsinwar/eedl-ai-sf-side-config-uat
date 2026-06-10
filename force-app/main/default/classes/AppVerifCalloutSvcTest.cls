@isTest
public class AppVerifCalloutSvcTest {
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
    }

    @isTest static void testQueueableCallout() {
        Account accParent = [SELECT Id FROM Account WHERE ParentId = null LIMIT 1];
        List<Contact> applicant = [SELECT Id FROM Contact WHERE LastName LIKE 'Contact%' LIMIT 1];
        hed__Program_Plan__c program = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c academicYear = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[0].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        );

        AI_Server_Job__c job = new AI_Server_Job__c(Application__c = app.Id, Status__c = 'queued');
        insert job;
        Set<Id> jobIds = new Set<Id>{job.Id};

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        System.enqueueJob(new ApplicationVerificationCalloutService(jobIds));
        Test.stopTest();
        System.assertEquals('queued', [SELECT Status__c FROM AI_Server_Job__c WHERE Id = :job.Id].Status__c);
    }

    // Simple mock class for HTTP callout
    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}