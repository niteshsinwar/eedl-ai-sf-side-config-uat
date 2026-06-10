@isTest
public class DocumentVerificationUtilsTest {

    @isTest static void testUtils() {
        Test.startTest();
        DocumentVerificationUtils utils = new DocumentVerificationUtils();
        System.assertNotEquals(null, utils);
        Test.stopTest();
    }

    @isTest static void testFormatBytes() {
        System.assertEquals('0 B', DocumentVerificationUtils.formatBytes(0));
        System.assertEquals('0 B', DocumentVerificationUtils.formatBytes(null));
        System.assertEquals('1 B', DocumentVerificationUtils.formatBytes(1));
        System.assertEquals('500 B', DocumentVerificationUtils.formatBytes(500));
        System.assert(DocumentVerificationUtils.formatBytes(1024).contains('KB'));
        System.assert(DocumentVerificationUtils.formatBytes(5120).contains('KB'));
        // MB case
        System.assert(DocumentVerificationUtils.formatBytes(1048576).contains('MB'));
        System.assert(DocumentVerificationUtils.formatBytes(5242880).contains('MB'));
    }

    @isTest static void testParseAndValidateId() {
        Id id = UserInfo.getUserId();
        System.assertEquals(id, DocumentVerificationUtils.parseAndValidateId(id, 'User'));

        // Blank ID case
        try {
            DocumentVerificationUtils.parseAndValidateId('', 'User');
            System.assert(false, 'Should throw');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('is required'));
        }

        // Invalid ID format case
        try {
            DocumentVerificationUtils.parseAndValidateId('invalid-id-format', 'Record');
            System.assert(false, 'Should throw');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('Invalid'));
        }
    }

    @isTest static void testFormatDate() {
        Date d = Date.newInstance(2020, 1, 2);
        System.assertEquals('2020-01-02', DocumentVerificationUtils.formatDate(d));
        System.assertEquals(null, DocumentVerificationUtils.formatDate(null));
        // Test with double digit month/day
        Date d2 = Date.newInstance(2023, 12, 25);
        System.assertEquals('2023-12-25', DocumentVerificationUtils.formatDate(d2));
    }

    @isTest static void testCreateErrorResponseMap() {
        Map<String, String> map1 = DocumentVerificationUtils.createErrorResponseMap('err');
        System.assertEquals('err', map1.get('error'));
    }

    @isTest static void testDebug() {
        DocumentVerificationUtils.debug('Test', 'msg');
        DocumentVerificationUtils.debug('Service', 'Another message');
    }

    @isTest static void testDocumentPayloadDTO() {
        Test.startTest();
        DocumentVerificationUtils.DocumentPayload payload = new DocumentVerificationUtils.DocumentPayload(
            'testFile.pdf',
            'PDF',
            'base64EncodedData',
            1024,
            Datetime.now()
        );
        Test.stopTest();

        System.assertEquals('testFile.pdf', payload.fileName);
        System.assertEquals('PDF', payload.fileExtension);
        System.assertEquals('base64EncodedData', payload.base64Data);
        System.assert(payload.fileSizeFormatted.contains('KB'));
        System.assertNotEquals(null, payload.lastModifiedDate);
    }

    @isTest static void testVerificationDataWrapperDTO() {
        Map<String, Object> recordData = new Map<String, Object>{
            'Name' => 'Test Record',
            'Status' => 'Active'
        };
        DocumentVerificationUtils.DocumentPayload payload = new DocumentVerificationUtils.DocumentPayload(
            'doc.pdf', 'PDF', 'data', 512, Datetime.now()
        );

        Test.startTest();
        DocumentVerificationUtils.VerificationDataWrapper wrapper = new DocumentVerificationUtils.VerificationDataWrapper(
            recordData,
            payload
        );
        Test.stopTest();

        System.assertEquals('Test Record', wrapper.recordData.get('Name'));
        System.assertEquals('doc.pdf', wrapper.documentPayload.fileName);
    }

    @isTest static void testFileInfoDTO() {
        Id testId = UserInfo.getUserId();

        Test.startTest();
        // Normal case
        DocumentVerificationUtils.FileInfo fileInfo = new DocumentVerificationUtils.FileInfo(
            testId, 'Document Title', 'PDF', 2048
        );
        // Blank extension case
        DocumentVerificationUtils.FileInfo fileInfo2 = new DocumentVerificationUtils.FileInfo(
            testId, 'No Extension', '', 1024
        );
        // Null size case
        DocumentVerificationUtils.FileInfo fileInfo3 = new DocumentVerificationUtils.FileInfo(
            testId, 'No Size', 'PDF', null
        );
        Test.stopTest();

        System.assertEquals(testId, fileInfo.id);
        System.assertEquals('Document Title', fileInfo.title);
        System.assertEquals('PDF', fileInfo.extension);
        System.assert(fileInfo.sizeLabel.contains('KB'));

        System.assertEquals('Unknown', fileInfo2.extension);
        System.assertEquals('0 B', fileInfo3.sizeLabel);
    }

    @isTest static void testFetchLatestDocumentVersion_NoDocument() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.startTest();
        try {
            DocumentVerificationUtils.fetchLatestDocumentVersion(acc.Id, 'Account');
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('No documents found'));
        }
        Test.stopTest();
    }

    @isTest static void testFetchLatestDocumentVersion_WithDocument() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'testdoc.pdf',
            VersionData = Blob.valueOf('Test content'),
            IsMajorVersion = true
        );
        insert cv;

        // Get ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link to Account
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = acc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        ContentVersion result = DocumentVerificationUtils.fetchLatestDocumentVersion(acc.Id, 'Account');
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Test Document', result.Title);
    }

    // Helper method to create ContentVersion with read-only fields using JSON deserialization
    private static ContentVersion createMockContentVersion(String title, Integer contentSize, String fileExtension) {
        String jsonStr = '{"Title":"' + title + '","ContentSize":' + contentSize + ',"FileExtension":"' + fileExtension + '"}';
        return (ContentVersion) JSON.deserialize(jsonStr, ContentVersion.class);
    }

    @isTest static void testValidateDocument_EmptyFile() {
        ContentVersion cv = createMockContentVersion('Empty File', 0, 'PDF');

        Test.startTest();
        try {
            DocumentVerificationUtils.validateDocument(cv);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('empty'));
        }
        Test.stopTest();
    }

    @isTest static void testValidateDocument_NullSize() {
        String jsonStr = '{"Title":"Null Size File","FileExtension":"PDF"}';
        ContentVersion cv = (ContentVersion) JSON.deserialize(jsonStr, ContentVersion.class);

        Test.startTest();
        try {
            DocumentVerificationUtils.validateDocument(cv);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('empty'));
        }
        Test.stopTest();
    }

    @isTest static void testValidateDocument_TooLarge() {
        ContentVersion cv = createMockContentVersion('Large File', 15728640, 'PDF'); // 15MB

        Test.startTest();
        try {
            DocumentVerificationUtils.validateDocument(cv);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('too large'));
        }
        Test.stopTest();
    }

    @isTest static void testValidateDocument_UnsupportedType() {
        ContentVersion cv = createMockContentVersion('Unsupported File', 1024, 'EXE');

        Test.startTest();
        try {
            DocumentVerificationUtils.validateDocument(cv);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('Unsupported file type'));
        }
        Test.stopTest();
    }

    @isTest static void testValidateDocument_BlankExtension() {
        String jsonStr = '{"Title":"No Extension File","ContentSize":1024,"FileExtension":""}';
        ContentVersion cv = (ContentVersion) JSON.deserialize(jsonStr, ContentVersion.class);

        Test.startTest();
        try {
            DocumentVerificationUtils.validateDocument(cv);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('Unsupported file type'));
        }
        Test.stopTest();
    }

    @isTest static void testValidateDocument_ValidDocument() {
        ContentVersion cv = createMockContentVersion('Valid File', 1024, 'PDF');

        Test.startTest();
        // Should not throw exception
        DocumentVerificationUtils.validateDocument(cv);
        Test.stopTest();

        System.assert(true, 'Validation passed for valid document');
    }

    @isTest static void testGetFilesForRecordLogic_NullRecordId() {
        Test.startTest();
        try {
            DocumentVerificationUtils.getFilesForRecordLogic(null);
            System.assert(false, 'Should throw exception');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assert(e.getMessage().contains('Record ID is required'));
        }
        Test.stopTest();
    }

    @isTest static void testGetFilesForRecordLogic_NoFiles() {
        Account acc = new Account(Name = 'Test Account No Files');
        insert acc;

        Test.startTest();
        List<DocumentVerificationUtils.FileInfo> files = DocumentVerificationUtils.getFilesForRecordLogic(acc.Id);
        Test.stopTest();

        System.assertEquals(0, files.size());
    }

    @isTest static void testGetFilesForRecordLogic_WithFiles() {
        Account acc = new Account(Name = 'Test Account With Files');
        insert acc;

        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Linked Document',
            PathOnClient = 'linked.pdf',
            VersionData = Blob.valueOf('File content here'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = acc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        List<DocumentVerificationUtils.FileInfo> files = DocumentVerificationUtils.getFilesForRecordLogic(acc.Id);
        Test.stopTest();

        System.assertEquals(1, files.size());
        System.assertEquals('Linked Document', files[0].title);
    }

    @isTest static void testDocumentVerificationException() {
        Test.startTest();
        try {
            throw new DocumentVerificationUtils.DocumentVerificationException('Test exception message');
        } catch (DocumentVerificationUtils.DocumentVerificationException e) {
            System.assertEquals('Test exception message', e.getMessage());
        }
        Test.stopTest();
    }
}