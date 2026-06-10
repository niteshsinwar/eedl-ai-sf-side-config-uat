@IsTest
public class EmploymentVerificationHandlerTest {

    @TestSetup
    static void setup() {
        // Create Account only once
        Account acc = TestDataFactory1.createTestAccount();
        acc.Name = 'Shared Emp Account ' + System.currentTimeMillis();
        update acc;
        
        Contact ct = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        Intake__c ay = TestDataFactory1.CreateAcademicYear('2024-2025', true);
        hed__Program_Plan__c prog = TestDataFactory1.createTestProgramWithAccount(acc.Id, ay.Id);
        hed__Term__c term = TestDataFactory1.createTestTerm(acc, prog);
    }

    @IsTest
    static void testGetEmploymentVerificationDataPackage_Positive() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Emp Account%' LIMIT 1];
        Contact ct = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        hed__Program_Plan__c prog = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c ay = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, acc.Id, ct.Id, prog.Id, ay.Id, 'Incomplete', 'Incomplete');

        hed__Affiliation__c aff = TestDataFactory1.CreateEmployment(ct.Id, acc.Id);

        ISB_Employment_Log__c log = new ISB_Employment_Log__c(
            Application__c = app.Id,
            Affiliation__c = aff.Id,
            Unique_Id__c = 'EMP-POS-' + System.currentTimeMillis()
        );
        insert log;

        DocumentChecklistItem dci = new DocumentChecklistItem(
            Name='Proof of income for self',
            ParentRecordId=app.Id);
        insert dci;

        insert new ContentVersion(
            Title='Proof Income', PathOnClient='income.pdf',
            VersionData=Blob.valueOf('test-content'),
            FirstPublishLocationId=dci.Id);

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            EmploymentVerificationHandler.getEmploymentVerificationDataPackage(log.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.documentPayload, 'Document should be found');
        System.assertEquals('pdf', result.documentPayload.fileExtension);
    }

    @IsTest
    static void testGetEmploymentVerificationDataPackage_MissingDoc() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Emp Account%' LIMIT 1];
        Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        hed__Application__c app2 = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            null, acc.Id, ct2.Id, null, null, 'Incomplete', 'Incomplete');

        hed__Affiliation__c aff2 = TestDataFactory1.CreateEmployment(ct2.Id, acc.Id);

        ISB_Employment_Log__c log2 = new ISB_Employment_Log__c(
            Application__c = app2.Id,
            Affiliation__c = aff2.Id,
            Unique_Id__c = 'EMP-NEG-' + System.currentTimeMillis()
        );
        insert log2;

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            EmploymentVerificationHandler.getEmploymentVerificationDataPackage(log2.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(null, result.documentPayload, 'Document should be null');
        System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
    }
    @IsTest
static void testGetEmploymentVerificationDataPackage_NullInput() {
    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        EmploymentVerificationHandler.getEmploymentVerificationDataPackage(null);
    Test.stopTest();

    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}

@IsTest
static void testGetEmploymentVerificationDataPackage_NoApplication() {
    Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Emp Account%' LIMIT 1];
    Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

    hed__Affiliation__c aff = TestDataFactory1.CreateEmployment(ct2.Id, acc.Id);

    ISB_Employment_Log__c log = new ISB_Employment_Log__c(
        Application__c = null, // No application
        Affiliation__c = aff.Id,
        Unique_Id__c = 'NO-APP-EMP-' + System.currentTimeMillis());
    insert log;

    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        EmploymentVerificationHandler.getEmploymentVerificationDataPackage(log.Id);
    Test.stopTest();

    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}



}