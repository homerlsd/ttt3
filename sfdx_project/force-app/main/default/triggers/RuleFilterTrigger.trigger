trigger RuleFilterTrigger on RuleFilter__c (after insert, after update, after delete, after undelete) {
    if(Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete || Trigger.isDelete)) {
        RuleTriggerHelper.validateRuleFiltersHandler(Trigger.isDelete ? Trigger.old : Trigger.new);
    }
}