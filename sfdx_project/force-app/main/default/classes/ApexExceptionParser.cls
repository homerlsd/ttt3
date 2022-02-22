global with sharing virtual class ApexExceptionParser implements IErrorParser {

    public static final Pattern PATTERN_VISUALFORCE_PAGE = Pattern.compile('Visualforce Page: \\/apex\\/([\\s\\S]+?)[\\n|\\r\\n|\\r]{2}');
    public static final Pattern PATTERN_WITH_ID = Pattern.compile('with id ([\\s\\S]{18});');
    public static final Pattern PATTERN_FAILED_TO = Pattern.compile('Failed to .* class \'?([^\' ]*?)\'? for job (id|ID) \'?(\\w*)\'?');
    public static final Pattern PATTERN_SCHEDULED_JOB = Pattern.compile('Scheduled job \'([^\']+)\' threw unhandled exception');
    public static final Pattern PATTERN_CLASS = Pattern.compile('(?=[\\n|\\r\\n|\\r]{2}((Class\\.|Trigger\\.|\\(System Code|External entry point)[\\S\\s]+?)([\\n|\\r\\n|\\r]{2}|\\Z))');
    public static final Pattern PATTERN_CAUSED_BY = Pattern.compile('(?=[\\n|\\r\\n|\\r]{2}(caused by:[\\S\\s]+?)([\\n|\\r\\n|\\r]{2}|\\Z))');
    public static final Pattern PATTERN_CLASS_NAME = Pattern.compile('Class ([\\s\\S]+?) : ');
    public static final Pattern PATTERN_CAUSED_BY_NAME = Pattern.compile('caused by: ([\\s\\S]+?):');
    public static final Pattern PATTERN_CAUSED_BY_NAME_LONG = Pattern.compile('caused by: [\\s\\S]+?: ([\\s\\S]+?)([\\n|\\r\\n|\\r]|\\Z)');
    public static final Pattern PATTERN_FAILED_BATCH = Pattern.compile('Failed to process batch for class \'([^\' ]+)\'');
    public static final Pattern PATTERN_BY_USER_OR_ORG_ID = Pattern.compile('by user/organization: ([\\s\\S]{15})/([\\s\\S]{15})');
    public static final String REGEX_SANDBOX = '^Sandbox[\\n|\\r\\n|\\r]{2}';
    public static final String REGEX_DEBUG_LOG = 'Debug Log:[\\S\\s]+$';
    public static final String REGEX_SOURCE_ORGANIZATION = 'Source organization: [^\\n|\\r\\n|\\r]*';
    public static final String REGEX_VISUALFORCE_PAGE = 'Visualforce Page: [\\s\\S]+?[\\n|\\r\\n|\\r]{2}';
    public static final String REGEX_EMAIL_PARTS = '[\\n|\\r\\n|\\r]{2}';
    public static final String REGEX_SYSTEM_CODE = '\\(System Code\\)([\\n|\\r\\n|\\r]|\\Z)';
    public static final String PARSER_TOKEN = 'Apex script unhandled';
    public static final String STACKTRACE_ENTRY_POINT = 'External entry point';
    public static final String STACKTRACE_CLASS = 'Class.';
    public static final String STACKTRACE_TRIGGER = 'Trigger.';
    public static final String PARSER_ERROR_TYPE_RECOMPILATION = 'Dependent class is invalid and needs recompilation';
    public static final String PARSER_SYSTEM_PREFIX = 'System.';
    public static final String PARSER_UNDEFINED_PREFIX = 'Undefined';
    public static final String PARSER_AREA_APEX = 'Apex';
    public static final String APEX_CATEGORY = 'Apex';
    public static final String PARSER_UNHANDLED_TRIGGER_EXCEPTION = 'Apex script unhandled trigger exception';
    public static final String PARSER_UNHANDLED_EXCEPTION = 'Apex script unhandled exception';
    public static final String PARSER_EXECUTE_PREFIX = '.execute';

    // GLOBAL

    global ApexExceptionParser() {}

    global virtual void init(String errorBody, String emailSubject, String emailSentFrom) {
        this.originalMessage = errorBody;
    }

    global virtual Boolean canProcess() {
        String msg = getError();
        return !String.isBlank(msg) && msg.containsIgnoreCase(PARSER_TOKEN);
    }

    global virtual void process() {
        parseErrorMessage();
    }

    global virtual String getError() {
        return this.originalMessage;
    }

    global virtual String getErrorSummary() {
        return this.summary;
    }

    global virtual String getErrorDetails() {
        return this.originalMessage;
    }

    global virtual String getVisualforcePage() {
        return this.visualforcePage;
    }

    global virtual String getRelatedId() {
        return this.relatedId;
    }

    global virtual String getRelatedObjectType() {
        return this.relatedId;
    }

    global virtual String getAsyncJobName() {
        return this.asyncJobName;
    }

    global virtual String getAsyncJobId() {
        return this.asyncJobId;
    }

    global virtual String getErrorType() {
        return this.errorType;
    }

    global virtual String getArea() {
        return this.area;
    }

    global virtual String getCategory() {
        return this.category;
    }

    global virtual String getUserId() {
        return this.userId;
    }

    global virtual String getOrganizationId() {
        return this.organizationId;
    }

    global virtual String getStackTrace() {
        return this.stacktrace;
    }

    global virtual String parseStackTrace() {
        return null;
    }

    global virtual String getMethodName() {
        return getMethodNameInternal();
    }

    global virtual String getHash1() {
        return LogService.generateHash_1(this.originalMessage);
    }

    global virtual String getHash2() {
        return LogService.generateHash_2(this.stacktrace);
    }

    global virtual String getHash3() {
        return LogService.generateHash_3(this.apexName);
    }

    global virtual String getPendingJobsInfo() {
        return null;
    }

    global virtual Decimal getTotalActiveSessions() {
        return null;
    }

    global virtual String getAuditTrail() {
        return null;
    }

    global virtual String getInstalledPackagesInfo() {
        return null;
    }

    global virtual String getNamespace() {
        return null;
    }

    global virtual String getDeploymentsInfo() {
        return null;
    }

    global virtual String getFlowVersion() {
        return null;
    }

    global virtual String getSalesforceErrorId() {
        return null;
    }

    global virtual List<ICustomErrorInfo> getCustomInfo() {
        List<ICustomErrorInfo> customFields = new List<ICustomErrorInfo>{
            new CategoryField(this.getCategory())
        };
        return customFields;
    }

    public class CategoryField implements ICustomErrorInfo {
        public String category;
        public CategoryField(String value) {
            this.category = value;
        }
        public String getValue() {
            return this.category;
        }
        public String getLogFieldName() {
            return Schema.sObjectType.Log__c.fields.Category__c.getName();
        }
    }

    global virtual List<Queueable> getAsyncMethods(Id logId) {
        List<Queueable> asyncMethods = new List<Queueable>();
        return asyncMethods;
    }

    global class ApexExceptionParserException extends Exception {}

    // PRIVATE

    private String originalMessage;
    private String summary;
    private String visualforcePage;
    private String relatedId;
    private String relatedObjectType;
    private String area;
    private String userId;
    private String organizationId;
    private String asyncJobName;
    private String asyncJobId;
    private String stacktrace;
    private String errorType;
    private String apexName;
    private String category;

    private void parseErrorMessage() {
        String message = this.getError();

        this.category = APEX_CATEGORY;

        /* Fix Email body from Sandbox */
        message = message.replaceAll(REGEX_SANDBOX, '');
        message = message.replaceAll(REGEX_DEBUG_LOG, '');
        message = message.replaceAll(REGEX_SOURCE_ORGANIZATION, '');


        Pattern p = PATTERN_VISUALFORCE_PAGE;
        Matcher pm = p.matcher(message);
        if (pm.find()) {
            this.visualforcePage = pm.group(1);
        }
        message = message.replaceAll(REGEX_VISUALFORCE_PAGE, '');

        List<String> emailParts = message.split(REGEX_EMAIL_PARTS);

        p = PATTERN_WITH_ID;
        pm = p.matcher(message);
        if (pm.find()) {
            this.relatedId = pm.group(1);
            String referenceName = null;
            try {
                referenceName = Id.valueOf(this.relatedId).getSObjectType().getDescribe().getName();
            } catch(Exception e) {}

            if (referenceName != null) {
                this.relatedObjectType = Id.valueOf(this.relatedId).getSObjectType().getDescribe().getLabel();
            }

        }

        // Find Async jobs information
        p = PATTERN_FAILED_TO;
        pm = p.matcher(message);
        if (pm.find()) {
            this.asyncJobName = pm.group(1);
            this.asyncJobId = pm.group(3);
        }
        if (String.isBlank(this.asyncJobName)) {
            p = PATTERN_SCHEDULED_JOB;
            pm = p.matcher(message);
            if (pm.find()) {
                this.asyncJobName = pm.group(1);
            }
        }

        p = PATTERN_CLASS;
        pm = p.matcher(message);

        List<String> stacktracesList = new List<String>();
        while (pm.find()) {
            stacktracesList.add(pm.group(1));
        }

        if (stacktracesList.size() > 0) {

            this.stacktrace = stacktracesList[stacktracesList.size() - 1];

            // fix "(System Code)" issue in stacktrace
            this.stacktrace  = this.stacktrace.replaceAll(REGEX_SYSTEM_CODE, '');

            if (String.isNotBlank(this.stacktrace ) &&
                !this.stacktrace.startsWith(STACKTRACE_ENTRY_POINT) &&
                !this.stacktrace.startsWith(STACKTRACE_CLASS) &&
                !this.stacktrace.startsWith(STACKTRACE_TRIGGER)) {
                throw new ApexExceptionParserException('Invalid stacktrace (' + this.stacktrace.abbreviate(255) + ')');
            }
        }

        p = PATTERN_CAUSED_BY;
        pm = p.matcher(message);

        List<String> causedByList = new List<String>();
        while (pm.find()) {
            causedByList.add(pm.group(1));
        }

        String summaryValue;
        if (causedByList.size() > 0) {

            String lastCauseBy = causedByList[causedByList.size() - 1];

            if (lastCauseBy.containsIgnoreCase(PARSER_ERROR_TYPE_RECOMPILATION)) {
                this.errorType = PARSER_ERROR_TYPE_RECOMPILATION;

                /*
                caused by: line 561, column 62: Dependent class is invalid and needs recompilation:
                Class talkdesk.ApexJobService : Dependent class is invalid and needs recompilation:
                Class talkdesk.CustomSettingsService : DML operation Delete not allowed on PermissionSetAssignment
                */

                p = PATTERN_CLASS_NAME;
                pm = p.matcher(lastCauseBy);
                while (pm.find()) {
                    this.apexName = pm.group(1);
                }

            } else {
                p = PATTERN_CAUSED_BY_NAME;
                pm = p.matcher(lastCauseBy);
                if (pm.find()) {
                    this.errorType = pm.group(1).replace(PARSER_SYSTEM_PREFIX, '');
                }
            }

            p = PATTERN_CAUSED_BY_NAME_LONG;
            pm = p.matcher(lastCauseBy);
            if (pm.find()) {
                summaryValue = pm.group(1);
            }
            // remove ":" from the end of Summary
            if (summaryValue != null && summaryValue.endsWith(':')) {
                summaryValue = summaryValue.substring(0, summaryValue.length()-1);
            }
        } else if (emailParts.size() == 2) {
            List<String> ppList = emailParts[1].split(': ');
            if (ppList.size() >= 3) {
                // Example of line:
                // OrderMain: System.LimitException: Too many SOQL queries: 101
                this.apexName = ppList[0];
                this.errorType = ppList[1].replace(PARSER_SYSTEM_PREFIX, '');
                ppList.remove(0);
                ppList.remove(0);
                summaryValue = String.join(ppList, ': ');
            } else {
                summaryValue = emailParts[1];
                this.errorType = PARSER_UNDEFINED_PREFIX;

                // Failed to process batch for class '<unknown>'
                p = PATTERN_FAILED_BATCH;
                pm = p.matcher(emailParts[1]);
                if (pm.find()) {
                    this.apexName = pm.group(1);
                }
            }
        }

        if (String.isNotBlank(summaryValue)) {
            this.summary = summaryValue.abbreviate(255);
        }
        else {
            this.summary = PARSER_UNDEFINED_PREFIX;
        }

        if (emailParts[0].containsIgnoreCase(PARSER_UNHANDLED_TRIGGER_EXCEPTION) ||
            emailParts[0].containsIgnoreCase(PARSER_UNHANDLED_EXCEPTION)) {
            this.area = PARSER_AREA_APEX;
        }

        p = PATTERN_BY_USER_OR_ORG_ID;
        pm = p.matcher(emailParts[0]);
        if (pm.find()) {
            this.userId = pm.group(1);
            this.organizationId = pm.group(2);
        }

        if(String.isBlank(this.errorType)) {
            this.errorType = PARSER_UNDEFINED_PREFIX;
        }

    }

    private String getMethodNameInternal() {
        if (String.isNotBlank(this.stacktrace)) {
            String apexName = LogService.getApexName(this.stacktrace);
            if (String.isNotBlank(apexName) && String.isBlank(this.apexName)) {
                this.apexName = apexName;
            }
        }
        if (
            String.isBlank(this.apexName) &&
            String.isNotBlank(this.asyncJobName) &&
            !this.asyncJobName.contains(' '))
        {
            this.apexName = this.asyncJobName;
        }
        // remove .execute from class name
        if (String.isNotBlank(this.apexName)) {
            this.apexName = this.apexName.replace(PARSER_EXECUTE_PREFIX, '');
        }
        return this.apexName;
    }


}