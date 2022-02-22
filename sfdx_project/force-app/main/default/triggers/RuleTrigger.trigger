trigger RuleTrigger on Rule__c (after insert, after update) {
    if(Trigger.isAfter && Trigger.isInsert) {
        RuleTriggerHelper.validateRulesHandlerOnInsert(Trigger.new, Trigger.oldMap);
    }
    if(Trigger.isAfter && Trigger.isUpdate) {
        RuleTriggerHelper.validateRulesHandlerOnUpdate(Trigger.new, Trigger.oldMap);
    }
}