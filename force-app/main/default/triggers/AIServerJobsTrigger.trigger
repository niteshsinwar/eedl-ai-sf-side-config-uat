trigger AIServerJobsTrigger on AI_Server_Job__c (after insert, after update, before insert, before update) {
    AIServerJobTriggerHandler handler = new AIServerJobTriggerHandler();
    
    if (Trigger.isAfter) {
        if (Trigger.isInsert) { 
            handler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
     if (Trigger.isBefore) {
        handler.handleBeforeUpdateInsert(Trigger.new);
     }
}