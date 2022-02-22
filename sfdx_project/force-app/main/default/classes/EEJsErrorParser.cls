global class EEJsErrorParser implements IErrorParser {

    private String originalMessage;
    private String originalMessageWithFilteredStacktrace;
    private String summary;
    private String fromAddress;
    private String visualforcePage;
    private String relatedId;
    private String relatedObjectType;
    private String area;
    private String userId;
    private String user;
    private String organizationId;
    private String asyncJobName;
    private String asyncJobId;
    private String stacktrace;
    private String errorType;
    private String apexName;
    private String page;
    private String jsName;
    private String jsType;
    private String jsMethod;
    private Boolean ignoreForJira = false;
    private Boolean ignoreForSplunk = false;

    global String getError() {
        return this.originalMessage;
    }

    global void setError(String message) {
        this.originalMessage = message;

        if (String.isBlank(message) ||
            !(message.containsIgnoreCase('Please review:') && message.containsIgnoreCase('--Error Bot')))
        {
            throw new ErrorParserException('Invalid error message format');
        }

        this.errorType = 'Error/JS';

        parseErrorMessage(message);
    }

    global void setFrom(String fromAddress) {
        this.fromAddress = fromAddress;
        if (String.isNotBlank(this.fromAddress)) {
            try {
                Pattern p = Pattern.compile('\\(([\\S\\s]+?)\\)');
                Matcher pm = p.matcher(this.fromAddress);
                if (pm.find()) {
                    this.user = pm.group(1);
                }
                String email = this.fromAddress.split(' ')[0];
                List<User> availableUsers = [SELECT Id FROM User WHERE Email = :email AND Name = :this.user LIMIT 1];
                if (availableUsers.size() > 0) {
                    this.userId = availableUsers[0].Id;
                }
            } catch(Exception e) {}

            // for Debug purposes
            if (fromAddress.contains('Dmitry Shnyrev')) {
                this.ignoreForSplunk = true;
                this.ignoreForJira = true;
            }

        }
    }

    global void setSubject(String subject) {

        subject = subject.replaceAll('Sandbox: ', '');

        // New Error/JS log Log-45085 has been created (EARTH ELEMENTS)
        if (!subject.startsWithIgnoreCase('New Error/JS')) {
            throw new ErrorParserException('Invalid error message format');
        }

    }

    private void parseErrorMessage(String message) {

        String messagePart;
        Pattern p = Pattern.compile('; message : ([\\S\\s]+?)\n\nAdditional Information:');
        Matcher pm = p.matcher(message);
        if (pm.find()) {
            messagePart = pm.group(1);
        }

        message = message.replaceAll('; message : [\\S\\s]+?\n\nAdditional Information:', '\n\nAdditional Information:');

        List<String> emailParts = message.split('[\\r\\n|\\n|\\r]{2}');

        try {
            this.page = emailParts[2].trim().split(' ')[1];
        } catch(Exception e) {}

        this.summary = emailParts[3].replace('Message:', '').trim();
        this.stacktrace = emailParts[4].replace('Description:', '').trim();
        this.stacktrace = this.stacktrace.split('; message :')[0].trim();
        String originalStacktrace = this.stacktrace;
        List<String> filteredStacktraceLines = new List<String>();
        List<String> stacktraceLines = this.stacktrace.split('[\\r\\n|\\n|\\r]');

        for (String sline : stacktraceLines) {
            if (sline.containsIgnoreCase('vendor.chunk.js')) {
                continue;
            }
            filteredStacktraceLines.add(sline);
        }

        this.stacktrace = String.join(filteredStacktraceLines, '\n');

        this.originalMessageWithFilteredStacktrace = this.originalMessage.replace(originalStacktrace, this.stacktrace);

        this.jsMethod = getMethod(this.stacktrace);

        if (filteredStacktraceLines.size() > 0) {
            List<String> lineChunks = filteredStacktraceLines[0].split('/');
            this.jsName = lineChunks[lineChunks.size()-1].split(':')[0];
        }
        if (String.isNotBlank(this.jsName)) {
            List<String> jsNameChunks = this.jsName.split('\\.');
            if (jsNameChunks.size() > 1) {
                this.jsType = jsNameChunks[jsNameChunks.size() - 2];
            }
        }

        // Pretify JSON in Additional information section
        String additionalInformation = null;
        p = Pattern.compile('Additional Information:([\\S\\s]+)$');
        pm = p.matcher(this.originalMessage);
        if (pm.find()) {
            additionalInformation = pm.group(1).trim();
        }
        if (String.isNotBlank(additionalInformation)) {
            p = Pattern.compile('\\{[\\s\\S]+\\}');
            pm = p.matcher(additionalInformation);
            if (pm.find()) {
                try {
                    String jsonPart = pm.group(0);
                    SYSTEM.DEBUG(jsonPart);
                    String jsonPartPretty = JSON.serializePretty(JSON.deserializeUntyped(jsonPart));
                    SYSTEM.DEBUG(jsonPartPretty);
                    this.originalMessage = this.originalMessage.replace(jsonPart, '\n' + jsonPartPretty +  '\n');
                } catch(Exception e) {}
            }
        }

        if (this.originalMessage.length() > 32000) {
            this.originalMessage = this.originalMessage.left(32000) + '...';
        }

        /* Add FromAddress to error body */
        if (String.isNotBlank(this.fromAddress)) {
            this.originalMessage = this.originalMessage + '\n\n---\n' + this.fromAddress;
        }

        // https://goldenratio.atlassian.net/browse/LOG-105
        if (message.contains('CUSTOM_EXCEPTION:')) {
            this.ignoreForJira = true;
            this.errorType = 'Custom';
        }

    }

    global String getErrorSummary() {
        return this.summary;
    }

    global String getErrorDetails() {
        return this.originalMessage;
    }

    global String getVisualforcePage() {
        return null;
    }

    global String getRelatedId() {
        return null;
    }

    global String getRelatedObjectType() {
        return null;
    }

    global String getAsyncJobName() {
        return null;
    }

    global String getAsyncJobId() {
        return null;
    }

    global String getErrorType() {
        return this.errorType;
    }

    global String getArea() {
        return null;
    }

    global String getUserId() {
        return this.userId;
    }

    global String getOrganizationId() {
        return null;
    }

    global String getStackTrace() {
        return this.stacktrace;
    }

    global String parseStackTrace() {
        return null;
    }

    global String getMethodName() {
        return null;
    }

    global String getHash1() {
        return generateHash_1(this.originalMessageWithFilteredStacktrace);
    }

    global String getHash2() {
        return generateHash_2(this.stacktrace);
    }

    global String getHash3() {
        return generateHash_3(this.jsName);
    }

    global String getPendingJobsInfo() {
        return null;
    }

    global Decimal getTotalActiveSessions() {
        return null;
    }

    global String getAuditTrail() {
        return null;
    }

    global String getInstalledPackagesInfo() {
        return null;
    }

    global String getNamespace() {
        return null;
    }

    global String getDeploymentsInfo() {
        return null;
    }

    global String getFlowVersion() {
        return null;
    }

    global String getSalesforceErrorId() {
        return null;
    }

    global List<ICustomErrorInfo> getCustomInfo() {
        List<ICustomErrorInfo> customFields = new List<ICustomErrorInfo>{
            // new PageField(this.page),
            // new UserField(this.user),
            // new JsNameField(this.jsName),
            // new JsTypeField(this.jsType),
            // new JsMethodField(this.jsMethod)
        };
        return customFields;
    }

    public class PageField implements ICustomErrorInfo {
        public String pageName;
        public PageField(String value) {
            this.pageName = value;
        }
        public String getValue() {
            return this.pageName;
        }
        public String getLogFieldName() {
            return 'Page__c';
        }
    }

    public class UserField implements ICustomErrorInfo {
        public String userName;
        public UserField(String value) {
            this.userName = value;
        }
        public String getValue() {
            return this.userName;
        }
        public String getLogFieldName() {
            return 'EEUser__c';
        }
    }

    public class JsNameField implements ICustomErrorInfo {
        public String jsName;
        public JsNameField(String value) {
            this.jsName = value;
        }
        public String getValue() {
            return this.jsName;
        }
        public String getLogFieldName() {
            return 'JS_Name__c';
        }
    }

    public class JsTypeField implements ICustomErrorInfo {
        public String jsType;
        public JsTypeField(String value) {
            this.jsType = value;
        }
        public String getValue() {
            return this.jsType;
        }
        public String getLogFieldName() {
            return 'JS_Layer__c';
        }
    }

    public class JsMethodField implements ICustomErrorInfo {
        public String jsMethod;
        public JsMethodField(String value) {
            this.jsMethod = value;
        }
        public String getValue() {
            return this.jsMethod;
        }
        public String getLogFieldName() {
            return 'JS_Method__c';
        }
    }

    global List<Queueable> getAsyncMethods(Id logId) {
        List<Queueable> asyncMethods = new List<Queueable>();
        asyncMethods.add(new LogService.StackTraceParseAsyncMethod(logId));
        // asyncMethods.add(new EELogService.SystemInfoMethod(logId));
        asyncMethods.add(new LogService.SlackMessageFromLogMethod(logId));
        if (!this.ignoreForJira) {
            asyncMethods.add(new LogService.JiraTaskFromLogMethod(logId));
        }
        if (!this.ignoreForSplunk) {
            asyncMethods.add(new LogService.SplunkRecordFromLogMethod(logId));
        }
        return asyncMethods;
    }

   private String generateHash_1(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        /* PROCESSING */
        // remove Page information
        value = value.replaceAll(this.page, '');
        // remove Additional Information section till the end of the email
        value = value.replaceAll('Additional Information:[\\S\\s]+$', '');
        // remove hash from JS: '"2":"drbhtuoobraoz2riuh06ai0r"'
        value = value.replaceAll('"2":"[\\w]+"', '');
        // remove all IDs (pseudo Ids)
        value = value.replaceAll('[\\w]{15,18}', '');
        // remove all Non-alphanum characters and whitespaces
        value = value.replaceAll('[\\W]', '');
        // remove all numbers
        value = value.replaceAll('[\\d]', '');
        // change all to lower case
        value = value.toLowerCase();

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return hash;
    }

    private String generateHash_2(String stacktrace) {
        if (String.isBlank(stacktrace)) {
            return null;
        }

        /* PROCESSING */
        List<String> stacktraceLines = stacktrace.split('[\\n|\\r\\n|\\r]');

        String value = stacktraceLines[0] + stacktraceLines[stacktraceLines.size() - 1];

        // remove line/column information
        value = value.replaceAll(':\\d+:\\d+', '');

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return hash;
    }

    private String generateHash_3(String jsName) {

        if (String.isBlank(jsName)) {
            return null;
        }

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(jsName)));

        return hash;
    }

    global static String getMethod(String stacktrace) {
        if (String.isBlank(stacktrace)) {
            return null;
        }

        /* PROCESSING */
        List<String> stacktraceLines = stacktrace.split('[\\n|\\r\\n|\\r]');

        String value = stacktraceLines[0];

        // remove line/column information
        value = value.split('@webpack')[0];

        return value;
    }

    public class ErrorParserException extends Exception {}

}