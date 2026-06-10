/**
 * @description This class provides shared utility methods, document operation functionalities,
 * Data Transfer Objects (DTOs), and a custom exception for the document verification process.
 * It is designed to be a foundational class, saveable independently.
 * @author Nitish Sinwar
 */
global with sharing class DocumentVerificationUtils {

    // --- General Constants ---
    public static final String ERROR_PREFIX = 'Verification Error: ';
    public static final Set<String> SUPPORTED_FILE_EXTENSIONS = new Set<String>{'PDF', 'JPEG', 'JPG', 'PNG', 'TIFF', 'TIF'};
    public static final Integer MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB
    public static final String DEBUG_SERVICE_NAME = 'DOC VERIFICATION UTILS';

    // --- Custom Exception Class ---
    /**
     * @description Custom exception for document verification processes.
     */
    public class DocumentVerificationException extends Exception {}

    // --- Inner DTO classes ---
    /**
     * @description Represents the payload of a document.
     */
    global class DocumentPayload {
        global String fileName;
        global String fileExtension;
        global String base64Data;
        global String fileSizeFormatted;
        global Datetime lastModifiedDate;

        /**
         * @description Constructor for DocumentPayload.
         * @param fileName The name of the file.
         * @param fileExtension The extension of the file.
         * @param base64Data The base64 encoded string of the file data.
         * @param sizeBytes The size of the file in bytes.
         * @param lastModifiedDate The last modified date of the document.
         */
        public DocumentPayload(String fileName, String fileExtension, String base64Data, Integer sizeBytes, Datetime lastModifiedDate) {
            this.fileName = fileName;
            this.fileExtension = fileExtension;
            this.base64Data = base64Data;
            this.fileSizeFormatted = DocumentVerificationUtils.formatBytes(sizeBytes);
            this.lastModifiedDate = lastModifiedDate;
        }
    }

    /**
     * @description Wrapper class for verification data, containing record data and document payload.
     */
    global class VerificationDataWrapper {
        global Map<String, Object> recordData;
        global DocumentPayload documentPayload;

        /**
         * @description Constructor for VerificationDataWrapper.
         * @param recordData A map containing data of the SObject record being verified.
         * @param documentPayload The DocumentPayload object associated with the record.
         */
        public VerificationDataWrapper(Map<String, Object> recordData, DocumentPayload documentPayload) {
            this.recordData = recordData;
            this.documentPayload = documentPayload;
        }
    }

    /**
     * @description Represents information about a file linked to a record.
     */
    global class FileInfo {
        global Id id;          // ContentDocumentId
        global String title;
        global String extension;
        global String sizeLabel;

        /**
         * @description Constructor for FileInfo.
         * @param docId The ContentDocumentId of the file.
         * @param title The title of the file.
         * @param extension The file extension.
         * @param size The size of the file in bytes.
         */
        public FileInfo(Id docId, String title, String extension, Integer size) {
            this.id = docId;
            this.title = title;
            this.extension = String.isBlank(extension) ? 'Unknown' : extension;
            this.sizeLabel = DocumentVerificationUtils.formatBytes(size == null ? 0 : size);
        }
    }

    // --- SHARED UTILITY METHODS ---
    /**
     * @description Parses a string to an Id and validates it.
     * @param idStr The string representation of the Id.
     * @param idNameForError A descriptive name for the Id used in error messages (e.g., "Education History ID").
     * @return The parsed Id.
     * @throws DocumentVerificationException if the Id string is blank or invalid.
     */
    public static Id parseAndValidateId(String idStr, String idNameForError) {
        if (String.isBlank(idStr)) {
            throw new DocumentVerificationException(ERROR_PREFIX + idNameForError + ' is required.');
        }
        try {
            return Id.valueOf(idStr);
        } catch (System.StringException e) {
            throw new DocumentVerificationException(ERROR_PREFIX + 'Invalid ' + idNameForError + ' format: ' + idStr);
        }
    }

    /**
     * @description Formats a Date object into "YYYY-MM-DD" string.
     * @param dt The Date object to format.
     * @return The formatted date string, or null if the input date is null.
     */
    public static String formatDate(Date dt) {
        if (dt == null) return null;
        return dt.year() + '-' + String.valueOf(dt.month()).leftPad(2, '0') + '-' + String.valueOf(dt.day()).leftPad(2, '0');
    }

    /**
     * @description Formats a file size in bytes into a human-readable string (B, KB, MB).
     * @param bytes The file size in bytes.
     * @return A string representing the formatted file size.
     */
    public static String formatBytes(Integer bytes) {
        if (bytes == null || bytes == 0) return '0 B';
        if (bytes < 1024) return bytes + ' B';
        Decimal kb = ((Decimal)bytes / 1024).setScale(1, System.RoundingMode.HALF_UP);
        if (kb < 1024) return kb + ' KB';
        Decimal mb = (kb / 1024).setScale(1, System.RoundingMode.HALF_UP);
        return mb + ' MB';
    }

    /**
     * @description Creates a map structure for a JSON error response.
     * @param errorMessage The error message string.
     * @return A map containing the error message under the 'error' key.
     */
    public static Map<String, String> createErrorResponseMap(String errorMessage) {
        return new Map<String, String>{ 'error' => errorMessage };
    }

    /**
     * @description Logs a debug message with a specified service/handler name.
     * @param serviceOrHandlerName The name of the service or handler logging the message.
     * @param message The debug message.
     */
    public static void debug(String serviceOrHandlerName, String message) {
        System.debug(LoggingLevel.INFO, '*** ' + serviceOrHandlerName.toUpperCase() + ' LOG: ' + message);
    }

    // --- SHARED DOCUMENT OPERATION METHODS ---
    /**
     * @description Fetches the latest ContentVersion of a document linked to a specific record.
     * @param linkedEntityId The Id of the record to which the document is linked.
     * @param recordTypeNameForError A descriptive name for the record type, used in error messages (e.g., "Education History Document").
     * @return The latest ContentVersion object.
     * @throws DocumentVerificationException if no document is found or if the version cannot be retrieved.
     */
    public static ContentVersion fetchLatestDocumentVersion(Id linkedEntityId, String recordTypeNameForError) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :linkedEntityId
            ORDER BY ContentDocument.LastModifiedDate DESC NULLS LAST, ContentDocument.CreatedDate DESC NULLS LAST
            LIMIT 1
        ];

        if (links.isEmpty()) {
            throw new DocumentVerificationException(
                ERROR_PREFIX + 'No documents found linked to this ' +
                recordTypeNameForError + ' (ID: ' + linkedEntityId + '). Please upload a document.'
            );
        }
        Id latestContentDocumentId = links[0].ContentDocumentId;
        debug(DEBUG_SERVICE_NAME, 'Latest ContentDocumentId: ' + latestContentDocumentId +
                                ' for ' + recordTypeNameForError + ' related to ID: ' + linkedEntityId);

        List<ContentVersion> versions = [
            SELECT Id, Title, VersionData, FileType, ContentSize, FileExtension, LastModifiedDate
            FROM ContentVersion
            WHERE ContentDocumentId = :latestContentDocumentId AND IsLatest = true
            LIMIT 1
        ];

        if (versions.isEmpty()) {
            throw new DocumentVerificationException(
                ERROR_PREFIX + 'Could not retrieve the document version for ' +
                recordTypeNameForError + ' (ID: ' + linkedEntityId + ')'
            );
        }
        return versions[0];
    }

    /**
     * @description Validates a ContentVersion based on size and supported file extensions.
     * @param docVersion The ContentVersion object to validate.
     * @throws DocumentVerificationException if the document is empty, too large, or has an unsupported file type.
     */
    public static void validateDocument(ContentVersion docVersion) {
        if (docVersion.ContentSize == null || docVersion.ContentSize == 0) {
            throw new DocumentVerificationException(ERROR_PREFIX + 'File is empty or its size cannot be determined: ' + docVersion.Title);
        }
        if (docVersion.ContentSize > MAX_FILE_SIZE_BYTES) {
            throw new DocumentVerificationException(
                ERROR_PREFIX + 'Document is too large. Max size: ' +
                formatBytes(MAX_FILE_SIZE_BYTES) +
                '. Your file (' + docVersion.Title + '): ' + formatBytes(docVersion.ContentSize)
            );
        }
        if (String.isBlank(docVersion.FileExtension) ||
            !SUPPORTED_FILE_EXTENSIONS.contains(docVersion.FileExtension.toUpperCase())) {
            throw new DocumentVerificationException(
                ERROR_PREFIX + 'Unsupported file type: ' + docVersion.FileExtension +
                ' for file ' + docVersion.Title + '. Supported: ' +
                String.join(new List<String>(SUPPORTED_FILE_EXTENSIONS), ', ') + '.'
            );
        }
    }

    /**
     * @description Retrieves a list of FileInfo objects for all documents linked to a record.
     * @param recordId The Id of the record.
     * @return A list of FileInfo objects.
     * @throws DocumentVerificationException if the recordId is null.
     */
    public static List<FileInfo> getFilesForRecordLogic(Id recordId) {
        debug(DEBUG_SERVICE_NAME, 'Getting files for record: ' + recordId);
        List<FileInfo> files = new List<FileInfo>();
        if (recordId == null) {
            throw new DocumentVerificationException(ERROR_PREFIX + 'Record ID is required to get files.');
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId]) {
            docIds.add(link.ContentDocumentId);
        }

        if (docIds.isEmpty()) {
            debug(DEBUG_SERVICE_NAME, 'No ContentDocumentIds found for record: ' + recordId);
            return files;
        }
        for (ContentVersion ver : [
            SELECT ContentDocumentId, Title, FileExtension, ContentSize FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true ORDER BY CreatedDate DESC
        ]) {
            files.add(new FileInfo(ver.ContentDocumentId, ver.Title, ver.FileExtension, ver.ContentSize));
        }
        debug(DEBUG_SERVICE_NAME, 'Returning ' + files.size() + ' files for record ' + recordId);
        return files;
    }
}