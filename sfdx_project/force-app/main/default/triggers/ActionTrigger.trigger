trigger ActionTrigger on Action__c (before insert, before update) {
  if(Trigger.isBefore && Trigger.isInsert) {
    ActionTriggerHelper.validateDefaultJiraAction(Trigger.new, null);
  }
  if(Trigger.isBefore && Trigger.isUpdate) {
    ActionTriggerHelper.validateDefaultJiraAction(Trigger.new, Trigger.oldMap);
  }
}