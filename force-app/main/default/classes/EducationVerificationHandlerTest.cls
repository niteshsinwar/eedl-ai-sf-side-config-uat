@IsTest
public class EducationVerificationHandlerTest {
 
    @TestSetup
    static void setup() {
        // Create Account only once
        Account acc = TestDataFactory1.createTestAccount();
        acc.Name = 'Shared Edu Account ' + System.currentTimeMillis();
        update acc;
        
        Contact ct = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        // Create supporting data that meets lookup filter requirements
        Degree__c degree = TestDataFactory1.createDegree();
        ISB_Classification_Master__c classification = TestDataFactory1.CreateclassificationMaster();
        Country__c country = TestDataFactory1.createCountry();
        State__c state = TestDataFactory1.createState(country.Id);
        Country_State_City__c city = TestDataFactory1.createCity(country.Id, state.Id);
    }

    @IsTest
    static void testGetEducationVerificationDataPackage_Positive() {
        Account accParent = [SELECT Id FROM Account WHERE Name LIKE 'Shared Edu Account%' LIMIT 1];
        List<Contact> applicant = TestDataFactory1.create5TestContactwithAccountId(accParent.Id);
        Degree__c degree = [SELECT Id FROM Degree__c LIMIT 1];
        degree.Name='Other';
        update degree;
        ISB_Classification_Master__c classification = TestDataFactory1.CreateclassificationMaster();
        Country__c country = TestDataFactory1.createCountry();
        State__c state = TestDataFactory1.createState(country.Id);
        Country_State_City__c city = TestDataFactory1.createCity(country.Id, state.Id);
        Account institute = TestDataFactory1.createTestInstituteAccount(accParent.Id, country.Id, state.Id, city.Id);
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            null, accParent.Id, applicant[0].Id, null, null, 'Incomplete', 'Incomplete'
        );
        Contact c = applicant[0];
        hed__Education_History__c eh = new hed__Education_History__c(
            hed__Contact__c = c.Id,
            Degree_Level__c = 'Professional Education',
            Institute__c = institute.Id,
            Degree_Name__c = degree.Id,
            Field_of_Study__c = classification.Id,
            country__c = country.Id,
            State__c = state.Id
        );
        insert eh;
        ISB_Education_Log__c log = new ISB_Education_Log__c(Application__c=app.Id, Education_History__c=eh.Id, Unique_Id__c='TestUniqueId1');
        insert log;
        DocumentChecklistItem dci = new DocumentChecklistItem(Name='Professional Marksheet or Transcript', ParentRecordId=app.Id);
        insert dci;
        ContentVersion cv = new ContentVersion(Title='UG Marksheet', PathOnClient='ug.pdf', VersionData=Blob.valueOf('abc'), FirstPublishLocationId=dci.Id);
        insert cv;
        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result = EducationVerificationHandler.getEducationVerificationDataPackage(log.Id);
        Test.stopTest();
        System.assertEquals('Professional Education', result.recordData.get('degreeLevel'));
        System.assertEquals('pdf', result.documentPayload.fileExtension);
    }


    @IsTest
    static void testGetEducationVerificationDataPackage_MissingDoc() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Edu Account%' LIMIT 1];
        Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        hed__Application__c app2 = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            null, acc.Id, ct2.Id, null, null, 'Incomplete', 'Incomplete');

        hed__Education_History__c eh2 = new hed__Education_History__c(
            hed__Contact__c = ct2.Id,
            Degree_Level__c = 'XII'
        );
        insert eh2;

        ISB_Education_Log__c log2 = new ISB_Education_Log__c(
            Application__c = app2.Id,
            Education_History__c = eh2.Id,
            Unique_Id__c = 'EDU-NEG-' + System.currentTimeMillis()
        );
        insert log2;

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            EducationVerificationHandler.getEducationVerificationDataPackage(log2.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(null, result.documentPayload, 'Document should be null');
        System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
    }
    @IsTest
static void testGetEducationVerificationDataPackage_NullInput() {
    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        EducationVerificationHandler.getEducationVerificationDataPackage(null);
    Test.stopTest();

    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}



    @IsTest
    static void testGetEducationVerificationDataPackage_FallbackPaths() {
        // Use a dummy ID to simulate missing log or missing fields
        Id dummyLogId = 'a3qfs0000000000AAA';
        DocumentVerificationUtils.VerificationDataWrapper resultMissingApp = EducationVerificationHandler.getEducationVerificationDataPackage(dummyLogId);
        System.assertNotEquals(null, resultMissingApp);

        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Edu Account%' LIMIT 1];
        Contact ct = [SELECT Id FROM Contact LIMIT 1];
        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(null, acc.Id, ct.Id, null, null, 'Incomplete', 'Incomplete');
    }
}