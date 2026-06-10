trigger AVSTrigger on Application_Verification_Summary__c (before insert, after update) {
    
    if (Trigger.isBefore && Trigger.isInsert) {
        AVSTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        AVSTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}