@IsTest
public class ApplicationVerificationHandlerTest {

    private static Account sharedAccount;
    private static Contact sharedContact;

    @TestSetup
    static void setup() {
        // Create Account only once with unique name to avoid duplicates
        sharedAccount = TestDataFactory1.createTestAccount();
        sharedAccount.Name = 'Shared Test Account ' + System.currentTimeMillis();
        update sharedAccount;
        
        sharedContact = TestDataFactory1.create5TestContactwithAccountId(sharedAccount.Id)[0];

        // Create supporting data
        Intake__c ay = TestDataFactory1.CreateAcademicYear('2024-2025', true);
        hed__Program_Plan__c prog = TestDataFactory1.createTestProgramWithAccount(sharedAccount.Id, ay.Id);
        hed__Term__c term = TestDataFactory1.createTestTerm(sharedAccount, prog);
    }

    @IsTest
    static void testGetApplicationVerificationDataPackage_Positive() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Account%' LIMIT 1];
        Contact ct = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        hed__Program_Plan__c prog = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Intake__c ay = [SELECT Id FROM Intake__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, acc.Id, ct.Id, prog.Id, ay.Id, 'Incomplete', 'Incomplete');

        // Attach document for positive test
        insert new ContentVersion(
            Title='ID Proof', PathOnClient='id.pdf',
            VersionData=Blob.valueOf('test-content'),
            FirstPublishLocationId=ct.Id);

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            ApplicationVerificationHandler.getApplicationVerificationDataPackage(app.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.documentPayload, 'Document should be found');
        System.assertEquals('pdf', result.documentPayload.fileExtension);
    }

    @IsTest
    static void testGetApplicationVerificationDataPackage_MissingDoc() {
        Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Account%' LIMIT 1];
        Contact ct2 = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];

        hed__Application__c app2 = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            null, acc.Id, ct2.Id, null, null, 'Incomplete', 'Incomplete');
        // No document attached - this will trigger fallback path

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper result =
            ApplicationVerificationHandler.getApplicationVerificationDataPackage(app2.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(null, result.documentPayload, 'Document should be null');
        System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
    }
    @IsTest
static void testGetApplicationVerificationDataPackage_NullInput() {
    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        ApplicationVerificationHandler.getApplicationVerificationDataPackage(null);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(null, result.documentPayload, 'Document should be null');
    System.assert(result.recordData.containsKey('Salesforce_data_issue_Summary'), 'Should contain error summary');
}



@IsTest
static void testGetApplicationVerificationDataPackage_DifferentIdProofTypes() {
    Account acc = [SELECT Id FROM Account WHERE Name LIKE 'Shared Test Account%' LIMIT 1];
    Contact ct = TestDataFactory1.create5TestContactwithAccountId(acc.Id)[0];
    
    // Update contact with different ID proof combinations
    ct.Passport_Number__c = 'P12345678';
    ct.Aadhar_Card_Number__c = 123456789012L; // Use Long type
    update ct;

    hed__Application__c app = TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
        null, acc.Id, ct.Id, null, null, 'Incomplete', 'Incomplete');

    insert new ContentVersion(
        Title='ID Proof Both', PathOnClient='id.pdf',
        VersionData=Blob.valueOf('test-content'), FirstPublishLocationId=ct.Id);

    Test.startTest();
    DocumentVerificationUtils.VerificationDataWrapper result =
        ApplicationVerificationHandler.getApplicationVerificationDataPackage(app.Id);
    Test.stopTest();

    System.assertEquals('Decide from Related Document', result.recordData.get('ID Proof Type'));
}

}