global with sharing virtual class FlowExceptionParser implements IErrorParser {

    public static final Pattern PATTERN_CAUSED_BY = Pattern.compile('caused by: ([\\s\\S]+?): ');
    public static final Pattern PATTERN_ERROR_OCCURRED = Pattern.compile('Error Occurred: ([\\s\\S]+?)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_CURRENT_USER = Pattern.compile('Current User: [\\s\\S]+? \\(([\\s\\S]+?)\\)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_ORGANISATION_ID = Pattern.compile('Org: [\\s\\S]+? \\(([\\s\\S]+?)\\)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_SFDC_ERROR_ID = Pattern.compile('Salesforce Error ID: ([\\s\\S]+)$');
    public static final Pattern PATTERN_FLOW_VERSION = Pattern.compile('Version: ([\\s\\S]+?)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_FLOW_API_NAME = Pattern.compile('Flow API Name: ([\\s\\S]+?)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_FLOW_ERROR_ELEMENT = Pattern.compile('Error element ([\\s\\S]+?)[\\n|\\r\\n|\\r]');
    public static final Pattern PATTERN_FLOW_TYPE = Pattern.compile('Type\\s*:\\s*(.*)');
    public static final Pattern PATTERN_PB_RELATED_ID = Pattern.compile('myVariable_(current|old|myEvent) = (.*)\\(([\\s\\S]{18})\\)');
    public static final Pattern PATTERN_FLOW_RELATED_ID = Pattern.compile('recordId = ([\\s\\S]{15,18}+)$');
    //$Record = Account (0014x00000JjRwoAAF)
    public static final Pattern PATTERN_FLOW_RELATED_RECORD_ID = Pattern.compile('\\$Record.=.(.*?)\\((.*?)\\)');
    public static final String FLOW_EXCEPTION = 'FlowException';
    public static final String FLOW_CATEGORY = 'Flow';
    public static final String PROCESS_BUILDER_CATEGORY = 'Process Builder';
    public static final String PROCESS_BUILDER_EXCEPTION = 'ProcessBuilderException';
    public static final String PARSER_AREA_FLOW = 'Flow';
    public static final String PARSER_AREA_PROCESS_BUILDER = 'Process Builder';
    public static final String PARSER_TOKEN = 'Flow Details';
    public static final String PARSER_SYSTEM_PREFIX = 'System.';
    public static final String PARSER_SUMMARY_UNDEFINED = 'Undefined';

    public static final String PB_TYPE_RECORD_CHANGE_PROCESS = 'Record Change Process';
    public static final String PB_TYPE_PLATFORM_EVENT_PROCESS = 'Platform Event Process';
    public static final String PB_TYPE_INVOCABLE_PROCESS = 'Invocable Process';
    public static final String UNDEFINED_TYPE = 'Undefined';

    // GLOBAL

    global FlowExceptionParser() {}

    global virtual void init(String errorBody, String emailSubject, String emailSentFrom) {
        this.originalMessage = (String.isNotBlank(errorBody)) ? errorBody.stripHtmlTags() : errorBody;
        this.stacktrace = errorBody;
        this.emailSubject = emailSubject;
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

    public String getValueForHash(String inputValue) {
        if(String.isNotBlank(inputValue)) {
            // remove flow guid
            inputValue = inputValue.replaceAll(LogService.REGEX_FLOW_GUID_PATTERN, '');
            // remove times
            inputValue = inputValue.replaceAll(LogService.REGEX_TIME_PATTERN, '');
            // remove all IDs (pseudo Ids)
            inputValue = inputValue.replaceAll(LogService.REGEX_ID_PATTERN, '');
            // remove all Non-alphanum characters and whitespaces
            inputValue = inputValue.replaceAll(LogService.REGEX_NON_ALPHANUMERIC_PATTERN, '');
            // remove all numbers
            inputValue = inputValue.replaceAll(LogService.REGEX_ALL_NUMBERS_PATTERN, '');
            // remove current user
            inputValue = inputValue.replaceAll(LogService.REGEX_FLOW_CURRENT_USER, '');
            // remove running user
            inputValue = inputValue.replaceAll(LogService.REGEX_FLOW_RUNNING_USER, '');
        }
        return inputValue;
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
        return this.relatedObjectType;
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
        return null;
    }

    global virtual String getHash1() {
        String value = getValueForHash(getErrorSummary()) + getFlowApiName() + getFlowVersion() + getFlowExecutionPath();
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));
        return hash;
    }

    global virtual String getHash2() {
        String value = getValueForHash(getFlowVersion() + getFlowApiName() + getErrorSummary());
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));
        return hash;
    }

    global virtual String getHash3() {
        String value = getValueForHash(getFlowApiName());
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));
        return hash;
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

    global virtual String getSalesforceErrorId() {
        return this.salesforceErrorId;
    }

    global virtual String getFlowVersion() {
        return this.flowVersion;
    }

    private String getFlowApiName() {
        return this.flowApiName;
    }

    private String getFlowExecutionPath() {
        return this.flowExecutionPath;
    }

    private String getFlowErrorElement() {
        return this.flowErrorElement;
    }

    global virtual List<ICustomErrorInfo> getCustomInfo() {
        List<ICustomErrorInfo> customFields = new List<ICustomErrorInfo>{
            new CategoryField(this.getCategory()),
            new FlowApiNameField(this.getFlowApiName())
        };
        return customFields;
    }

    public class FlowApiNameField implements  ICustomErrorInfo {
        public String flowAPIName;
        public FlowApiNameField(String value) {
            this.flowAPIName = value;
        }
        public String getValue() {
            return this.flowAPIName;
        }
        public String getLogFieldName() {
            return Schema.sObjectType.Log__c.fields.Flow_API_Name__c.getName();
        }
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

    global class FlowExceptionParserException extends Exception {}

    public String getCategory() {
        return this.category;
    }


    // PRIVATE
    public String originalMessage = null;
    public String emailSubject;
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
    private String flowVersion;
    private String salesforceErrorId;
    private String flowApiName;
    private String flowExecutionPath;
    private String flowErrorElement;
    private String category;

    private void parseErrorMessage() {

        this.area = PARSER_AREA_FLOW;

        String causedBy = getCausedByTokenValue();
        this.category = FLOW_CATEGORY;

        String flowType = getFlowTypeTokenValue();
        if(String.isNotBlank(flowType) &&
            (flowType.containsIgnoreCase(PB_TYPE_RECORD_CHANGE_PROCESS)
                || flowType.containsIgnoreCase(PB_TYPE_PLATFORM_EVENT_PROCESS)
                || flowType.containsIgnoreCase(PB_TYPE_INVOCABLE_PROCESS))) {
            this.category = PROCESS_BUILDER_CATEGORY;
            this.area = PARSER_AREA_PROCESS_BUILDER;
        }
        if(String.isNotBlank(causedBy)) {
            this.errorType = causedBy.replace(PARSER_SYSTEM_PREFIX, '');
        }
        if(String.isBlank(causedBy) && String.isNotBlank(flowType)) {
            this.errorType = flowType;
        }
        if(String.isBlank(this.errorType)) {
            this.errorType = UNDEFINED_TYPE;
        }

        String summaryValue = getErrorOccurredByTokenValue();
        this.summary = (String.isNotBlank(summaryValue)) ? summaryValue.abbreviate(255) : this.emailSubject;
        this.userId = getCurrentUserTokenValue();
        this.organizationId = getOrganizationIdTokenValue();
        this.salesforceErrorId = getSFDCErrorIdTokenValue();
        this.flowVersion = getFlowVersionTokenTokenValue();
        this.flowApiName = getFlowApiNameTokenValue();

        List<String> executionPath = getFlowExecutionPathList();
        if(!executionPath.isEmpty()) {
            this.flowExecutionPath = String.join(executionPath, ',');
            this.flowErrorElement = executionPath.get(executionPath.size() - 1);
        }

        this.relatedId = getRelatedIdTokenValue();
        this.relatedObjectType = getRelatedObjectTypeTokenValue();
    }

    private String getCausedByTokenValue() {
        return getStacktraceTokenValue(PATTERN_CAUSED_BY);
    }

    public String getErrorOccurredByTokenValue() {
        return getStacktraceTokenValue(PATTERN_ERROR_OCCURRED);
    }

    private String getOrganizationIdTokenValue() {
        return getStacktraceTokenValue(PATTERN_ORGANISATION_ID);
    }

    private String getFlowApiNameTokenValue() {
        return getStacktraceTokenValue(PATTERN_FLOW_API_NAME);
    }

    private String getFlowTypeTokenValue() {
        return getStacktraceTokenValue(PATTERN_FLOW_TYPE);
    }

    private String getCurrentUserTokenValue() {
        return getStacktraceTokenValue(PATTERN_CURRENT_USER);
    }

    private String getSFDCErrorIdTokenValue() {
        return getStacktraceTokenValue(PATTERN_SFDC_ERROR_ID);
    }

    private String getFlowVersionTokenTokenValue() {
        return getStacktraceTokenValue(PATTERN_FLOW_VERSION);
    }

    private List<String> getFlowExecutionPathList() {
        String stackTrace = getStackTrace();
        List<String> executionPathList = FlowService.getFlowExecutionPath(stackTrace);
        return executionPathList;
    }

    private String getRelatedIdTokenValue() {
        String result;
        Matcher pm = PATTERN_PB_RELATED_ID.matcher(getError());
        if(pm.find() && pm.groupCount() == 3) {
            result = pm.group(3);
        }
        if(String.isBlank(result)) {
            result = getStacktraceTokenValue(PATTERN_FLOW_RELATED_ID);
        }
        if(String.isBlank(result)) {
            pm = PATTERN_FLOW_RELATED_RECORD_ID.matcher(getError());
            if(pm.find()) {
                result = pm.group(2);
            }
        }

        return result;
    }

    private String getRelatedObjectTypeTokenValue() {
        String result;
        Matcher pm = PATTERN_PB_RELATED_ID.matcher(getError());
        if(pm.find() && pm.groupCount() == 3) {
            result = pm.group(2);
        }
        if(String.isBlank(result)) {
            result = getStacktraceTokenValue(PATTERN_FLOW_RELATED_RECORD_ID);
        }
        return result;
    }

    private String getStacktraceTokenValue(Pattern pattern) {
        String result;
        Pattern p = pattern;
        Matcher pm = p.matcher(getError());

        if (pm.find()) {
            result = pm.group(1);
        }

        return result;
    }


}