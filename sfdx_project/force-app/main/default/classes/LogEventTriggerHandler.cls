public with sharing class LogEventTriggerHandler {

    public static void logEventHandler(List<Log_Event__e> events) {
        List<Log__c> allLogs = new List<Log__c>();
        DateTime createAt = DateTime.now();

        for(Log_Event__e event : events) {
            List<Log__c> logs = (List<Log__c>)JSON.deserialize(event.body__c, List<Log__c>.class);
            allLogs.addAll(logs);
        }

        if(!allLogs.isEmpty()) {
            addOrgInfoForManualLog(allLogs, createAt);

            Database.SaveResult[] saveResults = Database.insert(allLogs, false);
            logSaveResults(saveResults, allLogs);
        }
    }

    public static void addOrgInfoForManualLog(List<Log__c> logs, DateTime createdAt) {
        for(Log__c log : logs) {
            log.Created_At__c = (log.Created_At__c == null) ? createdAt : log.Created_At__c;
            log.Organization_Id__c = (String.isBlank(log.Organization_Id__c)) ? UserInfo.getOrganizationId() : log.Organization_Id__c;
            Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(log.Organization_Id__c);
            if (corg != null) {
                log.Organization_Name__c = corg.Title__c;
                log.Organization_Url__c = corg.Instance_Url__c;
            }
            LogService.calculateHashes(log);
        }
    }

    private static void logSaveResults(Database.SaveResult[] results, Log__c[] queue) {
        Log__c[] logs = new Log__c[0];
        Integer index = 0;
        for(Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                String details = '';
                for (Database.Error err : sr.getErrors()) {
                    details += err.getStatusCode() + ': ' + err.getMessage() + '\n\n';
                    if(err.getFields().size() > 0) {
                        details += 'Fields: ' + err.getFields() + '\n\n';
                    }
                }

                details += JSON.serializePretty(queue[index]);

                logs.add(LogBuilder.getInstance()
                    .category('Error')
                    .summary('Unable to save log records')
                    .area('Pharos')
                    .type('Log Save Error')
                    .details(details)
                    .build());
            }
            index++;
        }

        if(logs.size() > 0) insert logs;
    }

}