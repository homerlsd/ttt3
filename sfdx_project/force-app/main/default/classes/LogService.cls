global with sharing class LogService {

    public static String ERROR_MESSAGE = 'An error occurred retrieving this information, please check the log records for details.';
    public static final String DEFAULT_PARSER_ERROR_CATEGORY = 'Error';
    public static final String PHAROS_HIDE_TOKEN = '(pharos)';
    public static final String PHAROS_CODE_TOKEN = 'pharos.';
    public static final String LOG_SERVICE_CLASS_NAME = 'LogService';

    private static Map<String, Id> getMapRecordTypes() {
        Map<String, Id> result = new Map<String, Id>();
        Map<String, Log_Category_Mapping_Setting__c> records = Log_Category_Mapping_Setting__c.getAll();

        if(!records.isEmpty()) {

            Map<String, Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.Log__c.getRecordTypeInfosByName();
            Map<String, Id> rtMapByDeveloperName = new Map<String, Id>();

            for(String rtName : rtMapByName.keySet()) {
                Schema.RecordTypeInfo rtInfo = rtMapByName.get(rtName);
                rtMapByDeveloperName.put(rtInfo.getDeveloperName(), rtInfo.getRecordTypeId());
            }

            List<Log_Category_Mapping_Setting__c> mappingRecords = records.values();
            for(Log_Category_Mapping_Setting__c categoryMapping : mappingRecords) {
                if(categoryMapping.Category__c != null && categoryMapping.Record_Type_Developer_Name__c != null) {
                    String rtDeveloperNameValue = categoryMapping.Record_Type_Developer_Name__c;
                    String categoryFieldValue = categoryMapping.Category__c;

                    Id rtId = rtMapByDeveloperName.get(rtDeveloperNameValue);
                    if(rtId != null) {
                        result.put(categoryFieldValue, rtId);
                    }
                }
            }
        }

        return result;
    }

    public static void assignRecordTypes(List<Log__c> newLogs, Map<Id, Log__c> mapOldLogs) {
        Map<String, Id> mapRecordTypes = getMapRecordTypes();
        for(Log__c log : newLogs) {
            Log__c oldLog = (mapOldLogs != null) ? mapOldLogs.get(log.Id) : null;

            if(oldLog == null
                && String.isNotBlank(log.Category__c)
                && mapRecordTypes.containsKey(log.Category__c)) {
                log.RecordTypeId = mapRecordTypes.get(log.Category__c);
            }
            else if(oldLog != null
                && oldLog.Category__c != log.Category__c
                && String.isNotBlank(log.Category__c)
                && mapRecordTypes.containsKey(log.Category__c)) {
                log.RecordTypeId = mapRecordTypes.get(log.Category__c);
            }
        }
    }


    // PUBLIC
    public static IErrorParser processor = null;

    public static void runAsyncMethods(List<Log__c> logs) {
        if (processor == null || Test.isRunningTest()) {
            return;
        }
        List<Queueable> asyncMethods = new List<Queueable>();
        for (Log__c log : logs) {
            asyncMethods.addAll(processor.getAsyncMethods(log.Id));
        }
        for (Queueable m : asyncMethods) {
            System.enqueueJob(m);
        }
    }

    public static Log__c createLogFromEmailBody(String emailBody, String emailSubject, String fromAddress, Datetime createdAt) {
        return createLogFromEmailBody(emailBody, emailSubject, fromAddress, createdAt, null);
    }

    public static Log__c createLogFromEmailBody(String emailBody, String emailSubject, String fromAddress, Datetime createdAt, String incomingOrganizationId) {

        if (emailBody == null) {
            throw new LogException('Error message is empty');
        }

        Log__c log;

        List<String> availableParsers = new List<String>();

        String customErrorParserClassName = ConfigUtil.PHAROS_SETTINGS.Custom_Error_Parser__c;
        if (customErrorParserClassName != null) {
            List<String> pp = customErrorParserClassName.split(';');
            for (String parserName : pp) {
                availableParsers.add(parserName.trim());
            }
        }

        availableParsers.add('ApexExceptionParser');
        availableParsers.add('FlowExceptionParser');
        if(ConfigUtil.SETTINGS.Enable_Email_To_Case_Error_Tracking__c == AdminService.ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED) {
            availableParsers.add('Email2CaseParser');
        }

        String parsingErrors = '';

        for (String parserName : availableParsers) {
            try {
                String customErrorParserClassNamespace = '';
                String customErrorParserClassLocalName = '';
                List<String> nameParts = parserName.split('\\.');
                if (nameParts.size() > 1) {
                    customErrorParserClassNamespace = nameParts[0];
                    customErrorParserClassLocalName = nameParts[1];
                } else {
                    customErrorParserClassLocalName = nameParts[0];
                }
                IErrorParser processor = (IErrorParser)Type.forName(customErrorParserClassNamespace, customErrorParserClassLocalName).newInstance();

                // Error processing
                processor.init(emailBody, emailSubject, fromAddress);

                if(!processor.canProcess()) continue;

                if (processor.getError() == null) {
                    throw new LogException('Error message not found. Please override getError() method to return error message.');
                }

                processor.process();
                String methodName = processor.getMethodName();
                if(String.isNotBlank(methodName)) {
                    List<String> methodNameParts = methodName.split('\\.');
                    if (!methodNameParts.isEmpty() && ![FIND 'Database.RaisesPlatformEvents' IN ALL FIELDS RETURNING ApexClass (Id, Name WHERE Name IN :methodNameParts AND Name != :LOG_SERVICE_CLASS_NAME)][0].isEmpty()) {
                        return null;
                    }
                }

                log = (Log__c)PermissionsUtil.newSObject(Schema.sObjectType.Log__c);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Category__c, DEFAULT_PARSER_ERROR_CATEGORY);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Created_At__c, createdAt);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Organization_Id__c, (String.isNotBlank(incomingOrganizationId)) ? incomingOrganizationId : processor.getOrganizationId());

                // Check if Connected Org for found OrgID exists to continue parsing
                Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(log.Organization_Id__c);
                if (corg == null) {
                    throw new LogService.LogException('Exception Email from Unknown source: ' + log.Organization_Id__c);
                }
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Is_Sandbox__c, corg.Is_Sandbox__c);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Organization_Name__c, corg.Title__c);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Organization_Url__c, corg.Instance_Url__c);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Summary__c, processor.getErrorSummary());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Details__c, processor.getErrorDetails());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Related_Id__c, processor.getRelatedId());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Related_Object_Type__c, processor.getRelatedObjectType());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Async_Job_Name__c, processor.getAsyncJobName());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Async_Job_Id__c, processor.getAsyncJobId());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Type__c, processor.getErrorType());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Area__c, processor.getArea());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.User_Id__c, processor.getUserId());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace__c, processor.getStackTrace());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c, processor.parseStackTrace());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Apex_Name__c, processor.getMethodName());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_1__c, processor.getHash1());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_2__c, processor.getHash2());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_3__c, processor.getHash3());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Pending_Jobs__c, processor.getPendingJobsInfo());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Total_Active_Sessions__c, processor.getTotalActiveSessions());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Setup_Audit_Trail__c, processor.getAuditTrail());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Installed_Packages__c, processor.getInstalledPackagesInfo());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Deploy_Results__c, processor.getDeploymentsInfo());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Flow_Version__c, processor.getFlowVersion());
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Salesforce_Error_Id__c, processor.getSalesforceErrorId());

                if(emailBody.containsIgnoreCase(PHAROS_HIDE_TOKEN) || emailBody.containsIgnoreCase(PHAROS_CODE_TOKEN)) {
                    PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Category__c, Logger.CATEGORY_PHAROS_ERROR);
                    PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Area__c, Logger.AREA_PHAROS_ERROR);
                }

                List<ICustomErrorInfo> customLogFields = processor.getCustomInfo();
                if (customLogFields != null) {
                    for (ICustomErrorInfo f : customLogFields) {
                        try {
                            PermissionsUtil.putSObjectField(log, f.getLogFieldName(), f.getValue());
                        }
                        catch(Exception e) {}
                    }
                }

                LogService.processor = processor;

                PermissionsUtil.performInsertDML(new List<Log__c>{log}, Schema.sObjectType.Log__c);
                return log;

            }
            catch(Exception e) {
                parsingErrors = parsingErrors + parserName + ':\n' +
                                e.getMessage() + '\n' +
                                e.getStackTraceString() + '\n\n';
                continue;
            }
        }

        throw new LogException(parsingErrors);
    }

    public static void copyLogFlagsFields(List<Log__c> newLogs) {
        Set<String> newLogsHashes = new Set<String>();
        Set<String> newLogsOrgIds = new Set<String>();
        Map<String, DateTime> mapCreaDataTimesByHash1 = new Map<String, DateTime>();
        Map<String, String> mapTrackerLinkByHash1 = new Map<String, String>();
        Map<String, DateTime> mapResolvedOnByHash1 = new Map<String, DateTime>();

        for(Log__c log : newLogs) {
            newLogsHashes.add(log.Hash_1__c);
            newLogsOrgIds.add(log.Organization_Id__c);
        }

        // copy values from last Log with same Hash1
        List<AggregateResult> lastLogWithHash1 = [
            SELECT MIN(First_Occurred_On__c) minCreatedDate, Hash_1__c hash1
            FROM Log__c
            WHERE Hash_1__c IN :newLogsHashes
            GROUP BY Hash_1__c
        ];
        for(AggregateResult aggregateResult : lastLogWithHash1) {
            String hash1 = (String)aggregateResult.get('hash1');
            DateTime minCreatedDatetime = (DateTime)aggregateResult.get('minCreatedDate');
            mapCreaDataTimesByHash1.put(hash1, minCreatedDatetime);
        }

        List<AggregateResult> logWithHash1AndTrackNumber = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? [
            SELECT Hash_1__c hash1, Bug_Tracker__c bugTracker
            FROM Log__c
            WHERE Hash_1__c IN :newLogsHashes
                AND Hash_1__c != NULL
                AND Bug_Tracker__c != NULL
                AND Resolved_On__c = NULL
            GROUP BY Hash_1__c, Bug_Tracker__c
        ] : [
            SELECT Hash_1__c hash1, Bug_Tracker__c bugTracker, Organization_Id__c orgId
            FROM Log__c
            WHERE Hash_1__c IN :newLogsHashes
                AND Organization_Id__c IN :newLogsOrgIds
                AND Hash_1__c != NULL
                AND Bug_Tracker__c != NULL
                AND Resolved_On__c = NULL
            GROUP BY Hash_1__c, Organization_Id__c, Bug_Tracker__c
        ];
        for(AggregateResult aggregateResult : logWithHash1AndTrackNumber) {
            String hash1 = (String)aggregateResult.get('hash1');
            String bugTracker = (String)aggregateResult.get('bugTracker');
            String key = hash1;
            if((ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c)) {
                String orgId = (aggregateResult.get('orgId') != null) ? (String)aggregateResult.get('orgId') : null;
                key = ((orgId != null) ? orgId : '') + hash1;
            }
            mapTrackerLinkByHash1.put(key, bugTracker);
        }

        List<AggregateResult> logWithHash1AndResolvedOn = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c) ? [
            SELECT Hash_1__c hash1, MAX(Resolved_On__c) resolvedOn
            FROM Log__c
            WHERE Hash_1__c IN :newLogsHashes
                AND Hash_1__c != NULL
                AND Bug_Tracker__c != NULL
                AND Resolved_On__c != NULL
            GROUP BY Hash_1__c
        ] : [
            SELECT Hash_1__c hash1, MAX(Resolved_On__c) resolvedOn, Organization_Id__c orgId
            FROM Log__c
            WHERE Hash_1__c IN :newLogsHashes
                AND Organization_Id__c IN :newLogsOrgIds
                AND Hash_1__c != NULL
                AND Bug_Tracker__c != NULL
                AND Resolved_On__c != NULL
            GROUP BY Hash_1__c, Organization_Id__c
        ];
        for(AggregateResult aggregateResult : logWithHash1AndResolvedOn) {
            String hash1 = (String)aggregateResult.get('hash1');
            DateTime resolvedOn = (DateTime)aggregateResult.get('resolvedOn');
            String key = hash1;
            if((ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c)) {
                String orgId = (aggregateResult.get('orgId') != null) ? (String)aggregateResult.get('orgId') : null;
                key = ((orgId != null) ? orgId : '') + hash1;
            }
            mapResolvedOnByHash1.put(key, resolvedOn);
        }

        for(Log__c log : newLogs) {
            String key = (!ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c)
                ? log.Hash_1__c
                : log.Organization_Id__c + log.Hash_1__c;

            DateTime minCreatedDate = mapCreaDataTimesByHash1.get(log.Hash_1__c);
            String bugTrackerLink = mapTrackerLinkByHash1.get(key);
            DateTime resolvedOn = mapResolvedOnByHash1.get(key);

            if(String.isNotBlank(bugTrackerLink)) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Bug_Tracker__c, bugTrackerLink);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Jira_Integration_Status__c, ConfigUtil.EXISTING_TICKET_LINKED_STATUS);
            }
            if(log.First_Occurred_On__c == null) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.First_Occurred_On__c, (minCreatedDate != null ? minCreatedDate : log.Created_At__c));
            }
            if(resolvedOn != null) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Regression__c, true);
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Regressed_On__c, log.Created_At__c);
            }
        }

    }

    public static Log__c calculateHashes(Log__c log) {
        if(String.isBlank(log.Hash__c)) {
            PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash__c, generateHash_0(log.Details__c));
        }
        if(String.isBlank(log.Hash_1__c)) {
            PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_1__c, generateHash_1(log.Details__c));
        }
        if(String.isNotBlank(log.Stacktrace__c)) {
            if (String.isBlank(log.Hash_2__c)) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_2__c, generateHash_2(log.Stacktrace__c));
            }
            String apexName = getApexName(log.Stacktrace__c);
            if (String.isNotBlank(apexName) && String.isBlank(log.Apex_Name__c)) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Apex_Name__c, apexName);
            }
            if (String.isBlank(log.Hash_3__c)) {
                PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_3__c, generateHash_3(log.Apex_Name__c));
            }
        }
        else if (String.isNotBlank(log.Apex_Name__c) && String.isBlank(log.Hash_3__c)) {
            PermissionsUtil.putSObjectField(log, Schema.sObjectType.Log__c.fields.Hash_3__c, generateHash_3(log.Apex_Name__c));
        }
        return log;
    }

    public static String generateHash_0(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        // fix "for job id '7070O00005VBQcW'" difference in duplacates
        // value = value.replaceAll('for job id \\\'[\\s\\S]{15,18}\\\'', 'for job id \'...\'');

        return EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));
    }

    public static final String REGEX_ID_PATTERN = '[\\w]{15,18}';
    public static final String REGEX_NON_ALPHANUMERIC_PATTERN = '[\\W]';
    public static final String REGEX_ALL_NUMBERS_PATTERN = '[\\d]';
    public static final String REGEX_FLOW_GUID_PATTERN = 'Interview GUID: ([\\s\\S]+?)[\\n|\\r\\n|\\r]';
    public static final String REGEX_TIME_PATTERN = '[AaPp][Mm]';
    public static final String REGEX_FLOW_CURRENT_USER = 'Current User: [\\s\\S]+? \\(([\\s\\S]+?)\\)[\\n|\\r\\n|\\r]';
    public static final String REGEX_FLOW_RUNNING_USER = 'How the Interview Started([\\s\\S]+?) started the flow interview';

    public static String generateHash_1(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        /* PROCESSING */
        // remove all IDs (pseudo Ids)
        value = value.replaceAll(REGEX_ID_PATTERN, '');
        // remove all Non-alphanum characters and whitespaces
        value = value.replaceAll(REGEX_NON_ALPHANUMERIC_PATTERN, '');
        // remove all numbers
        value = value.replaceAll(REGEX_ALL_NUMBERS_PATTERN, '');

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return hash;
    }

    public static String generateHash_2(String stacktrace) {
        if (String.isBlank(stacktrace)) {
            return null;
        }

        /* PROCESSING */
        List<String> stacktraceLines = stacktrace.split('[\\n|\\r\\n|\\r]');

        String value = stacktraceLines[0] + stacktraceLines[stacktraceLines.size() - 1];

        // remove line/column information
        value = value.replaceAll(' line ([\\s\\S]+?), column [\\s\\S]+?', '');

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return hash;
    }

    public static String generateHash_3(String apexName) {

        if (String.isBlank(apexName)) {
            return null;
        }

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(apexName)));

        return hash;
    }

    public static String getApexName(String stacktrace) {
        if (String.isBlank(stacktrace)) {
            return null;
        }

        List<String> stacktraceLines = stacktrace.split('[\\n|\\r\\n|\\r]');

        String value = stacktraceLines[stacktraceLines.size() - 1];

        // remove line/column information
        value = value.split(': line ')[0];

        value = value.replaceAll('^(Trigger\\.|Class\\.)', '');

        return value;
    }

    public class LogException extends Exception {}

}