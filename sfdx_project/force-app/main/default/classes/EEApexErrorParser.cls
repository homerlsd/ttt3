global class EEApexErrorParser implements IErrorParser {

    private String originalMessage;
    private String summary;
    private String fromAddress;
    private String visualforcePage;
    private String relatedId;
    private String relatedObjectType;
    private String area;
    private String user;
    private String userId;
    private String organizationId;
    private String asyncJobName;
    private String asyncJobId;
    private String stacktrace;
    private String errorType;
    private String apexName;
    private String page;
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

        // this.errorType = 'Custom';

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

        // New Error/Backend log Log-45049 has been created (EARTH ELEMENTS)
        if (!subject.startsWithIgnoreCase('New Error/Backend')) {
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

        // Get multiple stacktraces from email like this
/*
Please review: https://elements.my.salesforce.com/a4s0e000000XyQb

Environment: EARTH ELEMENTS

Page: clientPayments2.detail.tab

Message:
Insert failed. First exception on row 0; first error: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY, PaymentTrigger: execution of BeforeInsert caused by: System.DmlException: Insert failed. First exception on row 0; first error: CANNOT_INSERT_UPDATE_ACTIVATE_E...

Description:
Class.ClientPaymentService.applyPayment: line 720, column 1
Class.ClientPaymentService.make: line 163, column 1
External entry point
Class.EarthElementsBase.actionHandlerKeyNotSavepoint: line 70, column 1 ; message : Insert failed. First exception on row 0; first error: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY, PaymentTrigger: execution of BeforeInsert

caused by: System.DmlException: Insert failed. First exception on row 0; first error: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY, EEBillingTrigger: execution of AfterUpdate

caused by: System.DmlException: Update failed. First exception on row 0 with id a5O0e000001Gw9KEAS; first error: CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY, ClientInvoiceTrigger: execution of AfterUpdate

caused by: Utils.CustomException: GGAPPL-19061-1 was Paid!

Class.AcctSeedService: line 2303, column 1
Class.AcctSeedService: line 2226, column 1
Trigger.ClientInvoiceTrigger: line 49, column 1: []

Class.AcctSeedService.billingUpdate: line 2083, column 1
Trigger.EEBillingTrigger: line 4, column 1: []

Class.PaymentAcctSeedIntegration.beforeInsert: line 53, column 1
External entry point
Class.IntegrationService.beforeInsert: line 10, column 1
Trigger.PaymentTrigger: line 4, column 1: []


Additional Information:
ClientPaymentService {"action":"applyPayment","data":{"recordId":"a7O0e000000PRnvEAG","insertList":[{"Client_Payment__c":"a7O0e000000PRnvEAG","Client_Invoice__c":"a5O0e000001Gw9KEAS","Transaction__c":"a0w0e0000068HvzAAE","Applied_Amount__c":1765.71}]},"pageInfo":"clientPayments2.detail.tab"}


--Error Bot
*/
        if (String.isNotBlank(messagePart) && messagePart.containsIgnoreCase('caused by')) {
            List<String> ppList = messagePart.split('caused by: ');
            String pp = ppList[ppList.size()-1].trim();
            ppList = pp.split('[\\n|\\r\\n|\\r]{2}');
            if (ppList.size() > 1) {
                pp = '';
                for (Integer i=1; i <= ppList.size()-1; i++) {
                    pp = pp + ppList[i].replace(': []', '').trim() + '\n';
                }
                pp = pp.trim();
                if (String.isNotBlank(pp)) {
                    this.stacktrace = pp + '\n' + this.stacktrace;
                }
            }
        }

        // Parse caused by parts
        p = Pattern.compile('(?=[\\n|\\r\\n|\\r]{2}(caused by:[\\S\\s]+?)([\\n|\\r\\n|\\r]{2}|\\Z))');
        pm = p.matcher(this.originalMessage);

        List<String> causedByList = new List<String>();
        while (pm.find()) {
            causedByList.add(pm.group(1));
        }

        String summaryValue;
        if (causedByList.size() > 0) {

            String lastCauseBy = causedByList[causedByList.size() - 1];

            if (lastCauseBy.containsIgnoreCase('Dependent class is invalid and needs recompilation')) {
                this.errorType = 'Dependent class is invalid and needs recompilation';

                p = Pattern.compile('Class ([\\s\\S]+?) : ');
                pm = p.matcher(lastCauseBy);
                while (pm.find()) {
                    this.apexName = pm.group(1);
                }

            } else {
                p = Pattern.compile('caused by: ([\\s\\S]+?): ([\\s\\S]+)');
                pm = p.matcher(lastCauseBy);
                if (pm.find()) {
                    this.errorType = pm.group(1).replace('System.', '');
                    this.summary = pm.group(2);
                }
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
                    String jsonPartPretty = JSON.serializePretty(JSON.deserializeUntyped(jsonPart));
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
        if (String.isBlank(this.errorType)) {
            return 'Error/Backend';
        }
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
        if (String.isNotBlank(this.stacktrace)) {
            String apexName = EEApexErrorParser.getApexName(this.stacktrace);
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
            this.apexName = this.apexName.replace('.execute', '');
        }

        if (this.originalMessage.containsIgnoreCase('SQOL Queries Warning')) {
            this.ignoreForJira = true;
            this.apexName = null;
        }

        return this.apexName;
    }

    global String getHash1() {
        return generateHash_1(this.originalMessage);
    }

    global String getHash2() {
        return generateHash_2(this.stacktrace);
    }

    global String getHash3() {
        return generateHash_3(this.apexName);
    }

    private String generateHash_1(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        /* PROCESSING */
        if (value.containsIgnoreCase('Apex heap size too large')) {
            value = value.replaceAll('Description:[\\S\\s]+$', '');
        }
        // remove Page information
        value = value.replaceAll(this.page, '');
        // remove Additional Information section till the end of the email
        value = value.replaceAll('Additional Information:[\\S\\s]+$', '');
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
        value = value.replaceAll(' line ([\\s\\S]+?), column [\\s\\S]+?', '');

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return hash;
    }

    private String generateHash_3(String apexName) {

        if (String.isBlank(apexName)) {
            return null;
        }

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(apexName)));

        return hash;
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
            // new UserField(this.user)
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

    global static String getApexName(String stacktrace) {
        if (String.isBlank(stacktrace)) {
            return null;
        }

        /* PROCESSING */
        List<String> stacktraceLines = stacktrace.split('[\\n|\\r\\n|\\r]');

        // String value = stacktraceLines[stacktraceLines.size() - 1];
        String value = stacktraceLines[0];

        // remove line/column information
        value = value.split(': line ')[0];

        value = value.replaceAll('^(Trigger\\.|Class\\.)', '');

        /* HASH CALCULATING */
        String hash = EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));

        return value;
    }

    public class ErrorParserException extends Exception {}

}