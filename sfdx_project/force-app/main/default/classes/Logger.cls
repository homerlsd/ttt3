global with sharing class Logger {

    public static final String CATEGORY_PHAROS_ERROR = 'Pharos Error';
    public static final String AREA_PHAROS_ERROR = 'Pharos';

    /**
     * Get instance of the Logger.
     * Lazy loaded singleton.
     */
    global static Logger getInstance() {
        if (instance == null) {
            instance = new Logger();
        }
        return instance;
    }

    /**
     * Save log record to a buffer.
     * @param log -- log record to add.
     */
    global void add(Log__c log) {
        this.logsQueue.add(log);
    }

    /**
     * Persist buffered log records synchronously.
     * This method will perform a dml instantly.
     */
    global void flush() {
        flushInternal();
    }

    /**
     * Persist buffered log records asynchronously.
     * This method will perform a dml in a Queueable.
     */
    global void flushAsync() {
        asyncFlushInternal();
    }

    /**
     * Obtain a stack trace of the current execution.
     * Use this method to log stack traces when there's no Exception available.
     * Use the param to remove unwanted lines from the stack trace.
     * E.g. log util invocations that are not useful for debugging.
     * @param topOffset - number of stack trace lines to remove from the top.
     */
    global String getCurrentStackTrace(Integer topOffset) {
        return getCurrentStackTraceInternal(Math.Max(topOffset,0) + 1);
    }

    // PUBLIC
    public List<Log__c> logsQueue = new List<Log__c>();

    private static Logger instance = null;

    private Logger() {
    }

    private String getCurrentStackTraceInternal(Integer topOffset) {
        String st;
        try {
            Integer i = 1/0;
        } catch (Exception e) {
            st = e.getStackTraceString();
        }
        if(String.isBlank(st)) return null;

        String[] lines = new String[0];
        Integer count = 0;
        topOffset++;
        for(String stLine : st.split('\n')) {
            if(count >= topOffset) {
                lines.add(stLine);
            }
            count++;
        }
        return String.join(lines, '\n');
    }

    private void asyncFlushInternal() {
        System.enqueueJob(new AsyncLogSave(this.logsQueue));
    }

    private void flushInternal() {
        flushInternal(this.logsQueue);
    }

    private static void flushInternal(Log__c[] logsQueue) {
        if(logsQueue == null || logsQueue.size() == 0) return;

        //set org id on all the logs
        PermissionsUtil.putSObjectFields(logsQueue, Schema.sObjectType.Log__c.fields.Organization_Id__c, UserInfo.getOrganizationId(), false);

        if (ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c) {
            PassthroughtModeService.sendLogs(logsQueue);
            logsQueue.clear();
            return;
        }

        PermissionsUtil.publishLogEvent(logsQueue);

        logsQueue.clear();
        return;
    }

    public class AsyncLogSave implements Queueable, Database.AllowsCallouts {
        public List<Log__c> logsQueue = new List<Log__c>();
        public AsyncLogSave(List<Log__c> logsQueue) {
            this.logsQueue = logsQueue;
        }
        public void execute(QueueableContext context) {
            Logger.flushInternal(logsQueue);
        }
    }

    public void internalError(Exception e) {
        internalError(e, null);
    }

    public void internalError(Exception e, String relatedObjectID) {
        internalError(e, relatedObjectID, false);
    }

    public void internalError(Exception e, String area, String apexName) {
        internalError(e, null, true, area, apexName);
    }

    public void internalError(Exception e, String relatedObjectID, Boolean directInsert) {
        internalError(e, relatedObjectID, directInsert, null, null);
    }

    public void internalError(Exception e, String relatedObjectID, Boolean directInsert, String area, String apexName) {
        Log__c log = LogBuilder.getInstance()
            .category(CATEGORY_PHAROS_ERROR)
            .summary(e.getMessage())
            .area(AREA_PHAROS_ERROR)
            .type(String.isBlank(e.getTypeName()) ? AREA_PHAROS_ERROR : e.getTypeName())
            .stackTrace(e.getStackTraceString())
            .details(String.valueOf(e) + '\n\n' + e.getStackTraceString())
            .attribute(Schema.sObjectType.Log__c.fields.Apex_Name__c.getName(), area + ':' + apexName)
            .build();

        PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Related_Id__c, String.isNotBlank(relatedObjectID) ? relatedObjectID.abbreviate(18) : relatedObjectID);
        if(String.isNotBlank(relatedObjectID) && Schema.sObjectType.Log__c.getKeyPrefix() == relatedObjectID.substring(0, 3)) {
            PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Related_Object_Type__c, Schema.sObjectType.Log__c.getLabel());
        }
        PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Organization_Id__c, UserInfo.getOrganizationId());

        if(!directInsert) {
            PermissionsUtil.publishLogEvent(new List<Log__c>{log});
        }
        else {
            LogEventTriggerHandler.addOrgInfoForManualLog(new List<Log__c>{log}, DateTime.now());
            PermissionsUtil.performInsertDML(new List<Log__c>{log});
        }
    }

    public void internalError(List<Exception> exceptions, String relatedObjectID, Boolean directInsert, String area, List<String> apexNames) {
        List<Log__c> logs = new List<Log__c>();
        for (Integer i = 0; i < exceptions.size(); i++) {
            Log__c log = LogBuilder.getInstance()
                .category(CATEGORY_PHAROS_ERROR)
                .summary(exceptions.get(i).getMessage())
                .area(AREA_PHAROS_ERROR)
                .type(String.isBlank(exceptions.get(i).getTypeName()) ? AREA_PHAROS_ERROR : exceptions.get(i).getTypeName())
                .stackTrace(exceptions.get(i).getStackTraceString())
                .details(String.valueOf(exceptions.get(i)) + '\n\n' + exceptions.get(i).getStackTraceString())
                .attribute(Schema.SObjectType.Log__c.fields.Apex_Name__c.getName(), area + ':' + apexNames.get(i))
                .build();
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Related_Id__c, String.isNotBlank(relatedObjectID) ? relatedObjectID.abbreviate(18) : relatedObjectID);
            if (String.isNotBlank(relatedObjectID) && Schema.SObjectType.Log__c.getKeyPrefix() == relatedObjectID.substring(0, 3)) {
                PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Related_Object_Type__c, Schema.SObjectType.Log__c.getLabel());
            }
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Organization_Id__c, UserInfo.getOrganizationId());
            logs.add(log);
        }
        if (!directInsert) {
            PermissionsUtil.publishLogEvent(logs);
        }
        else {
            LogEventTriggerHandler.addOrgInfoForManualLog(logs, Datetime.now());
            PermissionsUtil.performInsertDML(logs);
        }
    }

    public void internalError(Map<String, Exception> exceptions, Boolean directInsert, String area, String apexName) {
        List<Log__c> logs = new List<Log__c>();
        for (String relatedObjectID : exceptions.keySet()) {
            Log__c log = LogBuilder.getInstance()
                .category(CATEGORY_PHAROS_ERROR)
                .summary(exceptions.get(relatedObjectID).getMessage())
                .area(AREA_PHAROS_ERROR)
                .type(String.isBlank(exceptions.get(relatedObjectID).getTypeName()) ? AREA_PHAROS_ERROR : exceptions.get(relatedObjectID).getTypeName())
                .stackTrace(exceptions.get(relatedObjectID).getStackTraceString())
                .details(String.valueOf(exceptions.get(relatedObjectID)) + '\n\n' + exceptions.get(relatedObjectID).getStackTraceString())
                .attribute(Schema.SObjectType.Log__c.fields.Apex_Name__c.getName(), area + ':' + apexName)
                .build();
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Related_Id__c, String.isNotBlank(relatedObjectID) ? relatedObjectID.abbreviate(18) : relatedObjectID);
            if (String.isNotBlank(relatedObjectID) && Schema.SObjectType.Log__c.getKeyPrefix() == relatedObjectID.substring(0, 3)) {
                PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Related_Object_Type__c, Schema.SObjectType.Log__c.getLabel());
            }
            PermissionsUtil.putSObjectField(log, Schema.SObjectType.Log__c.fields.Organization_Id__c, UserInfo.getOrganizationId());
            logs.add(log);
        }
        if (!directInsert) {
            PermissionsUtil.publishLogEvent(logs);
        }
        else {
            LogEventTriggerHandler.addOrgInfoForManualLog(logs, Datetime.now());
            PermissionsUtil.performInsertDML(logs);
        }
    }

}