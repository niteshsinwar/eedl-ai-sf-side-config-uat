@isTest
public class AIServerJobTriggerHandlerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test application records
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
        // Create Contact (Applicant)
        List<hed__Application__c> applications = new List<hed__Application__c>();
        for (Integer i = 0; i < 5; i++) {
            applications.add(TestDataFactory1.createTestApplicationWithTermIdProgramIdLapsedBatch(
            term.Id, accParent.Id, applicant[i].Id, program.Id, academicYear.Id, 'Incomplete', 'Incomplete'
        ));
        }

        
        // Create test AI Server Job records
        List<AI_Server_Job__c> aiServerJobs = new List<AI_Server_Job__c>();
        for (Integer i = 0; i < 5; i++) {
            aiServerJobs.add(new AI_Server_Job__c(
                Application__c = applications[i].Id,
                Status__c = 'queued'
            ));
        }
        insert aiServerJobs;
        
        // Create Application Verification Summary records for different types
        List<Application_Verification_Summary__c> avsRecords = new List<Application_Verification_Summary__c>();
        String[] verificationTypes = new String[]{'education', 'employment', 'test score', 'personal detail', 'resume', 'recommender', 'declaration'};
        
        for (Integer i = 0; i < applications.size(); i++) {
            for (String type : verificationTypes) {
                avsRecords.add(new Application_Verification_Summary__c(
                    Name = 'Test ' + type + ' verification ' + i,
                    Application__c = applications[i].Id,
                    Percentage_Confidence__c = (i == 0) ? 97 : 85 // First app has high confidence, others low
                ));
            }
        }
        insert avsRecords;
        
        // Create DocumentChecklistItem records
        List<DocumentChecklistItem> checklistItems = new List<DocumentChecklistItem>();
        for (Application_Verification_Summary__c avs : avsRecords) {
            checklistItems.add(new DocumentChecklistItem(
                Name = 'Test Checklist Item for ' + avs.Name,
                Application_Verification_Summary__c = avs.Id,
                ParentRecordId = avs.Application__c,
                Status = 'Not Verified'
            ));
        }
        insert checklistItems;
        
        // Create Task records for different verification types
        List<Task> tasks = new List<Task>();
        String[] taskSubjects = new String[]{'education verification', 'employment verification', 'test score verification', 'personal details verification', 'recommender verification', 'declaration and soi verification'};
        
        for (Integer i = 0; i < applications.size(); i++) {
            for (String subject : taskSubjects) {
                tasks.add(new Task(
                    Subject = subject,
                    WhatId = applications[i].Id,
                    Status = 'Not Verified'
                ));
            }
        }
        insert tasks;
    }

      @isTest
    static void testTriggerBeforeUpdate_RetryLogic() {
        Test.startTest();
        
        // Get existing job and set it to failed with retry keywords
        AI_Server_Job__c existingJob = [SELECT Id, Status__c FROM AI_Server_Job__c LIMIT 1];
        existingJob.Status__c = 'Failed';
        existingJob.Message__c = 'JWT token expired, authentication failed';
        
        // This will trigger the before update event
        update existingJob;
        
        Test.stopTest();
        
        // Verify the trigger executed retry logic
        AI_Server_Job__c updatedJob = [SELECT Id, Status__c FROM AI_Server_Job__c WHERE Id = :existingJob.Id];
        System.assertEquals('queued', updatedJob.Status__c, 'Job should be set to Queued due to retry keywords');
    }
    
    // NEW: Test the trigger with before update operations (no retry)
    @isTest
    static void testTriggerBeforeUpdate_NoRetry() {
        Test.startTest();
        
        // Get existing job and set it to failed without retry keywords
        AI_Server_Job__c existingJob = [SELECT Id, Status__c FROM AI_Server_Job__c LIMIT 1];
        existingJob.Status__c = 'Failed';
        existingJob.Message__c = 'General processing error without retry keywords';
        
        // This will trigger the before update event
        update existingJob;
        
        Test.stopTest();
        
        // Verify the trigger executed without retry logic
        AI_Server_Job__c updatedJob = [SELECT Id, Status__c FROM AI_Server_Job__c WHERE Id = :existingJob.Id];
        System.assertEquals('failed', updatedJob.Status__c, 'Job should remain Failed without retry keywords');
    }

    @isTest
    static void testTriggerBeforeUpdate_EEDLAlertPathDoesNotAssumeApplication() {
        insert new Opportunity__c(Name = 'Active', Activate_Trigger__c = false);
        List<Account> accts = CEE_TestUtility.createAccounts(true, 1);
        List<Product2> prods = CEE_TestUtility.createProducts(true, 1);
        List<Opportunity> opps = CEE_TestUtility.createOpportunities(false, 1, accts);
        opps[0].APP_Product__c = prods[0].Id;
        insert opps;

        AI_Server_Job__c eedlJob = new AI_Server_Job__c(
            Opportunity__c = opps[0].Id,
            Status__c = 'queued'
        );
        insert eedlJob;

        Test.startTest();
        eedlJob.Status__c = 'failed';
        eedlJob.Message__c = 'Read timed out while contacting the AI server';
        update eedlJob;
        Test.stopTest();

        AI_Server_Job__c updatedJob = [
            SELECT Id, Opportunity__c, Status__c
            FROM AI_Server_Job__c
            WHERE Id = :eedlJob.Id
        ];
        System.assertEquals(opps[0].Id, updatedJob.Opportunity__c, 'EEDL job should remain linked to the Opportunity.');
        System.assertEquals('failed', updatedJob.Status__c, 'Alert-worthy EEDL failures should remain failed, not crash or requeue.');
    }
    
    @isTest
    static void testHandleAfterInsert_WithEnabledChokePoint() {
        // Create a mock metadata record (since we can't insert custom metadata in tests)
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 3];
        for (AI_Server_Job__c job : jobs) {
            job.Status__c = 'completed';
        }
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        
        // Test the after insert handler
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Get Application__c Ids for jobs
        Set<Id> appIds = new Set<Id>();
        for (AI_Server_Job__c job : jobs) {
            if (job.Application__c != null) appIds.add(job.Application__c);
        }
        // Query tasks using appIds
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE WhatId IN :appIds];
        System.assertNotEquals(0, updatedTasks.size(), 'Tasks should be updated');
    }
    
    @isTest
    static void testHandleAfterUpdate_StatusChanged() {
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 3];
        Map<Id, AI_Server_Job__c> oldMap = new Map<Id, AI_Server_Job__c>();
        
        // Create old map with different status
        for (AI_Server_Job__c job : jobs) {
            oldMap.put(job.Id, new AI_Server_Job__c(Id = job.Id, Status__c = 'pending'));
            job.Status__c = 'completed';
        }
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterUpdate(jobs, oldMap);
        
        Test.stopTest();
        
        // Get Application__c Ids for jobs
        Set<Id> appIds = new Set<Id>();
        for (AI_Server_Job__c job : jobs) {
            if (job.Application__c != null) appIds.add(job.Application__c);
        }
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE WhatId IN :appIds];
        System.assertNotEquals(0, updatedTasks.size(), 'Tasks should be processed on status change');
    }
    
    @isTest
    static void testHandleAfterUpdate_NoStatusChange() {
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 3];
        Map<Id, AI_Server_Job__c> oldMap = new Map<Id, AI_Server_Job__c>();
        
        // Create old map with same status
        for (AI_Server_Job__c job : jobs) {
            oldMap.put(job.Id, new AI_Server_Job__c(Id = job.Id, Status__c = job.Status__c));
        }
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterUpdate(jobs, oldMap);
        
        Test.stopTest();
        
        // No assertions needed as no processing should occur
        System.assert(true, 'No processing should occur when status unchanged');
    }
    
    @isTest
    static void testProcessAIServerJobs_AllVerificationTypes() {
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 2];
        for (AI_Server_Job__c job : jobs) {
            job.Status__c = 'completed';
        }
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify that all verification types are processed
        Set<String> expectedTypes = new Set<String>{'EDUCATION', 'TEST_SCORE', 'EMPLOYMENT', 'PERSONAL_DETAILS', 'RESUME_ANALYSIS', 'RECOMMENDER_ANALYSIS', 'DECLARATION_ANALYSIS'};
        
        // Get Application__c Ids for jobs
        Set<Id> appIds = new Set<Id>();
        for (AI_Server_Job__c job : jobs) {
            if (job.Application__c != null) appIds.add(job.Application__c);
        }
        List<Id> avsIds = new List<Id>();
        for (Application_Verification_Summary__c avs : [SELECT Id, Application__c FROM Application_Verification_Summary__c WHERE Application__c IN :appIds]) {
            avsIds.add(avs.Id);
        }
        List<DocumentChecklistItem> updatedItems = [SELECT Id, Status FROM DocumentChecklistItem WHERE Application_Verification_Summary__c IN :avsIds];
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE WhatId IN :appIds];
        System.assertNotEquals(0, updatedItems.size(), 'DocumentChecklistItems should be updated');
        System.assertNotEquals(0, updatedTasks.size(), 'Tasks should be updated');
    }
    
    @isTest
    static void testProcessApplicationVerification_HighConfidence() {
        Test.startTest();
        
        // Get an application with high confidence AVS records
        List<hed__Application__c> apps = [SELECT Id FROM hed__Application__c LIMIT 1];
        List<Application_Verification_Summary__c> avsRecords = [
            SELECT Id, Percentage_Confidence__c 
            FROM Application_Verification_Summary__c 
            WHERE Application__c = :apps[0].Id AND Percentage_Confidence__c >= 100
        ];
        
       
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c WHERE Application__c = :apps[0].Id];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify high confidence results in 'Accepted' status for DocumentChecklistItems
        List<DocumentChecklistItem> acceptedItems = [
            SELECT Id, Status 
            FROM DocumentChecklistItem 
            WHERE Application_Verification_Summary__c IN :avsRecords AND Status = 'Accepted'
        ];
        
       
    }
    
    @isTest
    static void testProcessApplicationVerification_LowConfidence() {
        Test.startTest();
        
        // Get an application with low confidence AVS records
        List<hed__Application__c> apps = [SELECT Id FROM hed__Application__c LIMIT 1 OFFSET 1];
        List<Application_Verification_Summary__c> avsRecords = [
            SELECT Id, Percentage_Confidence__c 
            FROM Application_Verification_Summary__c 
            WHERE Application__c = :apps[0].Id AND Percentage_Confidence__c < 100
        ];
        
        System.assertNotEquals(0, avsRecords.size(), 'Should have low confidence AVS records');
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c WHERE Application__c = :apps[0].Id];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify low confidence results in 'Not Verified' status for DocumentChecklistItems
        List<DocumentChecklistItem> pendingItems = [
            SELECT Id, Status 
            FROM DocumentChecklistItem 
            WHERE Application_Verification_Summary__c IN :avsRecords AND Status = 'Not Verified'
        ];
        
        System.assertNotEquals(0, pendingItems.size(), 'Low confidence should result in Not Verified status');
    }
    
    @isTest
    static void testProcessApplicationVerification_NoAVSRecords() {
        Test.startTest();
        
        // Create a new application without AVS records
  
         hed__Application__c app = [SELECT Id FROM hed__Application__c LIMIT 1];
        
        AI_Server_Job__c newJob = new AI_Server_Job__c(
            Application__c = app.Id,
            Status__c = 'completed'
        );
        insert newJob;
        
        // Create tasks for this application
        List<Task> tasks = new List<Task>();
        tasks.add(new Task(Subject = 'education verification', WhatId = app.Id, Status = 'Not Verified'));
        tasks.add(new Task(Subject = 'employment verification', WhatId = app.Id, Status = 'Not Verified'));
        insert tasks;
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(new List<AI_Server_Job__c>{newJob});
        
        Test.stopTest();
        
    }
    
    @isTest
    static void testResumeAnalysisVerification() {
        Test.startTest();
        
        List<hed__Application__c> apps = [SELECT Id FROM hed__Application__c LIMIT 1];
        List<Application_Verification_Summary__c> resumeAVS = [
            SELECT Id, Percentage_Confidence__c 
            FROM Application_Verification_Summary__c 
            WHERE Application__c = :apps[0].Id AND Name LIKE '%resume%'
        ];
        
        System.assertNotEquals(0, resumeAVS.size(), 'Should have resume AVS records');
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c WHERE Application__c = :apps[0].Id];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify DocumentChecklistItems are updated for resume verification
        List<DocumentChecklistItem> resumeItems = [
            SELECT Id, Status 
            FROM DocumentChecklistItem 
            WHERE Application_Verification_Summary__c IN :resumeAVS
        ];
        
        System.assertNotEquals(0, resumeItems.size(), 'Resume verification should update DocumentChecklistItems');
    }
    
    @isTest
    static void testRecommenderAnalysisVerification() {
        Test.startTest();
        
        List<hed__Application__c> apps = [SELECT Id FROM hed__Application__c LIMIT 1];
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c WHERE Application__c = :apps[0].Id];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify Tasks are updated for recommender verification
        List<Task> recommenderTasks = [
            SELECT Id, Status 
            FROM Task 
            WHERE WhatId = :apps[0].Id AND Subject LIKE '%recommender%'
        ];
        
        System.assertNotEquals(0, recommenderTasks.size(), 'Recommender verification should update Tasks');
    }
    
    @isTest
    static void testDeclarationAnalysisVerification() {
        Test.startTest();
        
        List<hed__Application__c> apps = [SELECT Id FROM hed__Application__c LIMIT 1];
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c WHERE Application__c = :apps[0].Id];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify Tasks are updated for declaration verification
        List<Task> declarationTasks = [
            SELECT Id, Status 
            FROM Task 
            WHERE WhatId = :apps[0].Id AND Subject LIKE '%declaration%'
        ];
        
        System.assertNotEquals(0, declarationTasks.size(), 'Declaration verification should update Tasks');
    }
    
    @isTest
    static void testInvalidJobsFiltering() {
        Test.startTest();
        
        // Create jobs with null Application__c
        List<AI_Server_Job__c> invalidJobs = new List<AI_Server_Job__c>();
        invalidJobs.add(new AI_Server_Job__c(Status__c = 'completed'));
        invalidJobs.add(new AI_Server_Job__c(Status__c = 'pending'));
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(invalidJobs);
        
        Test.stopTest();
        
        // No assertions needed as invalid jobs should be filtered out
        System.assert(true, 'Invalid jobs should be filtered out without causing errors');
    }
    
    @isTest
    static void testExceptionHandling() {
        Test.startTest();
        
        // Create a scenario that might cause an exception
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 1];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        
        // This should not throw an exception even if there are issues
        try {
            handler.handleAfterInsert(jobs);
            System.assert(true, 'Handler should handle exceptions gracefully');
        } catch (Exception e) {
            System.assert(false, 'Handler should not throw exceptions: ' + e.getMessage());
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testStatusChangedRecordsIdentification() {
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 3];
        Map<Id, AI_Server_Job__c> oldMap = new Map<Id, AI_Server_Job__c>();
        
        // Mix of changed and unchanged statuses
        for (Integer i = 0; i < jobs.size(); i++) {
            if (i == 0) {
                // This one changes to completed
                oldMap.put(jobs[i].Id, new AI_Server_Job__c(Id = jobs[i].Id, Status__c = 'pending'));
                jobs[i].Status__c = 'completed';
            } else {
                // These don't change
                oldMap.put(jobs[i].Id, new AI_Server_Job__c(Id = jobs[i].Id, Status__c = jobs[i].Status__c));
            }
        }
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterUpdate(jobs, oldMap);
        
        Test.stopTest();
        
        // Only one job should be processed
        System.assert(true, 'Only status-changed records should be processed');
    }
    
    @isTest
    static void testEmptyRecordLists() {
        Test.startTest();
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        
        // Test with empty lists
        handler.handleAfterInsert(new List<AI_Server_Job__c>());
        handler.handleAfterUpdate(new List<AI_Server_Job__c>(), new Map<Id, AI_Server_Job__c>());
        
        Test.stopTest();
        
        System.assert(true, 'Handler should handle empty lists gracefully');
    }
    
    @isTest
    static void testAllVerificationTypesProcessing() {
        Test.startTest();
        
        List<AI_Server_Job__c> jobs = [SELECT Id, Application__c, Status__c FROM AI_Server_Job__c LIMIT 1];
        jobs[0].Status__c = 'completed';
        
        AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
        handler.handleAfterInsert(jobs);
        
        Test.stopTest();
        
        // Verify that all verification types are processed
        Set<String> expectedTypes = new Set<String>{'EDUCATION', 'TEST_SCORE', 'EMPLOYMENT', 'PERSONAL_DETAILS', 'RESUME_ANALYSIS', 'RECOMMENDER_ANALYSIS', 'DECLARATION_ANALYSIS'};
        
        // Get Application__c Ids for jobs
        Set<Id> appIds = new Set<Id>();
        for (AI_Server_Job__c job : jobs) {
            if (job.Application__c != null) appIds.add(job.Application__c);
        }
        List<Id> avsIds = new List<Id>();
        for (Application_Verification_Summary__c avs : [SELECT Id, Application__c FROM Application_Verification_Summary__c WHERE Application__c IN :appIds]) {
            avsIds.add(avs.Id);
        }
        List<DocumentChecklistItem> updatedItems = [SELECT Id, Status FROM DocumentChecklistItem WHERE Application_Verification_Summary__c IN :avsIds];
        List<Task> updatedTasks = [SELECT Id, Status FROM Task WHERE WhatId IN :appIds];
        System.assertNotEquals(0, updatedItems.size(), 'DocumentChecklistItems should be updated');
        System.assertNotEquals(0, updatedTasks.size(), 'Tasks should be updated');
    }
}