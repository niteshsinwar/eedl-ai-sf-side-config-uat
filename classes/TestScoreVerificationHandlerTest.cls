@IsTest
public class TestScoreVerificationHandlerTest {

    @TestSetup
    static void setup() {
        // Create Account only once
        Account acc = TestDataFactory1.createTestAccount();
        acc.Name = 'Shared Test Score Account ' + System.currentTimeMillis();
        update acc;
        
        Contact ct = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        Intake__c ay = TestDataFactory1.CreateAcademicYear('2024-2025', true);
        hed__Program_Plan__c prog = TestDataFactory1.createTestProgramWithAccount(acc.Id, ay.Id);
        hed__Term__c term = TestDataFactory1.createTestTerm(acc, prog);
    }

    @IsTest
    static void testGetTestScoreVerificationDataPackage_Positive_GMAT() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Score Account%' LIMIT 1];
        Contact ct = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        hed__Program_Plan__c prog = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c ay = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, acc.Id, ct.Id, prog.Id, ay.Id, 'Incomplete', 'Incomplete');

        hed__Test__c testTest = TestDataFactory1.createTestForGMATFOCUSWithStatus(ct.Id, app.Id);
        TestDataFactory1.createTestScoreGMATFOCUS(testTest.Id, ct.Id, app.Id);

        DocumentChecklistItem dci = new DocumentChecklistItem(
            Name='GMAT Score Card',
            ParentRecordId=app.Id);
        insert dci;

        insert new ContentVersion(
            Title='GMAT', PathOnClient='gmat.pdf',
            VersionData=Blob.valueOf('test-content'),
            FirstPublishLocationId=dci.Id);

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            TestScoreVerificationHandler.getTestScoreVerificationDataPackage(testTest.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.documentPayload, 'Document should be found');
        System.assertEquals('pdf', result.documentPayload.fileExtension);
    }

    @IsTest
    static void testGetTestScoreVerificationDataPackage_MissingDoc() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Score Account%' LIMIT 1];
        Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        hed__Application__c app2 = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            null, acc.Id, ct2.Id, null, null, 'Incomplete', 'Incomplete');

        hed__Test__c test2 = TestDataFactory1.createTestForGMATFOCUSWithStatus(ct2.Id, app2.Id);
        // No Test Score record and no ContentVersion - triggers fallback path

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            TestScoreVerificationHandler.getTestScoreVerificationDataPackage(test2.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(null, result.documentPayload, 'Document should be null');
        System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
    }
    @IsTest
static void testGetTestScoreVerificationDataPackage_NullInput() {
    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        TestScoreVerificationHandler.getTestScoreVerificationDataPackage(null);
    Test.stopTest();

    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}

@IsTest
static void testGetTestScoreVerificationDataPackage_NoApplication() {
    Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Score Account%' LIMIT 1];
    Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

    hed__Test__c testRecord = TestDataFactory1.createTestForGMATFOCUSWithStatus(ct2.Id, null); // No application

    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        TestScoreVerificationHandler.getTestScoreVerificationDataPackage(testRecord.Id);
    Test.stopTest();

    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}


@IsTest
static void testGetTestScoreVerificationDataPackage_ExceptionHandling() {
    Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Score Account%' LIMIT 1];
    Contact ct = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];

    hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
        null, acc.Id, ct.Id, null, null, 'Incomplete', 'Incomplete');

    hed__Test__c testRecord = TestDataFactory1.createTestForGMATFOCUSWithStatus(ct.Id, app.Id);

    Test.startTest();
    try {
        DocumentVerificationUtils.VerificationDataWrapper result =
            TestScoreVerificationHandler.getTestScoreVerificationDataPackage(testRecord.Id);
        
        // Should handle gracefully even if there are internal exceptions
        System.assertNotEquals(null, result, 'Result should not be null even with errors');
        
    } catch (Exception e) {
        // If an exception occurs, ensure it's handled properly
        System.assert(false, 'Handler should not throw exceptions: ' + e.getMessage());
    }
    Test.stopTest();
}

@IsTest 
static void testGetTestScoreVerificationDataPackage_WithTestScore() {
    Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Score Account%' LIMIT 1];
    Contact ct = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
    hed__Program_Plan__c prog = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
    Intake__c ay = [SELECT Id FROM Intake__c LIMIT 1];
    hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

    hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
        term.Id, acc.Id, ct.Id, prog.Id, ay.Id, 'Incomplete', 'Incomplete');

    hed__Test__c testRecord = TestDataFactory1.createTestForGMATFOCUSWithStatus(ct.Id, app.Id);
    
    // Create Test Score record to test the "found" path
    TestDataFactory1.createTestScoreGMATFOCUS(testRecord.Id, ct.Id, app.Id);

    DocumentChecklistItem dci = new DocumentChecklistItem(
        Name='GMAT Score Card', ParentRecordId=app.Id);
    insert dci;

    insert new ContentVersion(
        Title='GMAT Complete', PathOnClient='gmat.pdf',
        VersionData=Blob.valueOf('test-content'), FirstPublishLocationId=dci.Id);

    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        TestScoreVerificationHandler.getTestScoreVerificationDataPackage(testRecord.Id);
    Test.stopTest();

    System.assertNotEquals(null, result.documentPayload, 'Document should be found');
    System.assertEquals('pdf', result.documentPayload.fileExtension);
}

}