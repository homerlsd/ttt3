global class InvocableTestClass {

  
  
  @InvocableMethod(label='Process Platform Event Logs' description='Process Platform Event Logs' category= 'Apex')
      global static List<ID> processPlatformEvents(List<Log_Event__e> events) {
        LogEventTriggerHandler.logEventHandler(events);
        return new List<Id>();
  }

}