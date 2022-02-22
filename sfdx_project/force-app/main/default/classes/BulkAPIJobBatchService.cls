public with sharing class BulkAPIJobBatchService {

    public static final String BULK_API = 'Bulk API';

    public static final String JOB_TYPE_BULK_API_V1 = 'Classic';
    public static final String JOB_TYPE_BULK_API_V2 = 'V2Ingest';

    public static final Integer BULK_LOGS_QUERY_WINDOW_DAYS = -10;

    public static final Map<String, String> MAP_DELIMITERS = new Map<String, String>{
            'BACKQUOTE' => '`',
            'CARET' => '^',
            'COMMA' => ',',
            'PIPE' => '|',
            'SEMICOLON' => ';',
            'TAB' => '  '
    };

    public static final Map<String, String> MAP_LINE_ENDINGS = new Map<String, String>{
            'LF' => '\n',
            'CRLF' => '\r\n'
    };

    public static Boolean isPassthroughMode() {
        return ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c && String.isNotBlank(ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Email__c);
    }

    public static Log__c createLog(Connected_Org__c corg, Job job, Set<String> setErrors) {
        String type = '';
        if (job.jobType == JOB_TYPE_BULK_API_V1) {
            type = 'Bulk API v1';
        } else if (job.jobType == JOB_TYPE_BULK_API_V2) {
            type = 'Bulk API v2';
        }
        List<String> lstErrors = new List<String>(setErrors);
        lstErrors.sort();
        BulkAPIProperty bulkAPIProperty = new BulkAPIProperty();
        bulkAPIProperty.apiVersion = type;
        if (String.isNotBlank(job.systemModstamp)) {
            try {
                bulkAPIProperty.validUntilDate = Datetime.valueOfGmt(job.systemModstamp.replace('T', ' ').replace('.000', '').replace('+0000', '')).addDays(7);
            } catch (Exception e) {}
        }
        return LogBuilder.getInstance()
                .category('Apex')
                .summary('Object: ' + job.obj +
                        ' Operation: ' + job.operation +
                        ' Number Records Processed: ' + job.numberRecordsProcessed +
                        ' Number Records Failed: ' + job.numberRecordsFailed)
                .area(Schema.getGlobalDescribe().get(job.obj).getDescribe().getLabelPlural())
                .type(type)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Id__c.Name, corg.Name)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Name__c.Name, corg.Title__c)
                .attribute(Schema.SObjectType.Log__c.fields.Organization_Url__c.Name, corg.Instance_Url__c)
                .attribute(Schema.SObjectType.Log__c.fields.Async_Job_Id__c.Name, job.id)
                .attribute(Schema.SObjectType.Log__c.fields.Stacktrace__c.Name, JSON.serialize(bulkAPIProperty))
                .attribute(Schema.SObjectType.Log__c.fields.Hash__c.Name, LogService.generateHash_0(String.join(lstErrors, ',')))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_1__c.Name, LogService.generateHash_1(job.obj + job.operation + job.jobType + String.join(lstErrors, ',')))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_2__c.Name, LogService.generateHash_2(job.obj + job.operation + job.jobType + job.contentType + job.apiVersion + job.createdById))
                .attribute(Schema.SObjectType.Log__c.fields.Hash_3__c.Name, LogService.generateHash_3(job.obj + job.operation + job.jobType))
                .build();
    }

    public static void insertLog(List<Log__c> lstLogs) {
        if (isPassthroughMode()) {
            PassthroughtModeService.sendLogs(lstLogs);
        } else {
            PermissionsUtil.performInsertDML(lstLogs, Schema.SObjectType.Log__c);
        }
    }

    public static void createContentVersion(Log__c log, Job job, Blob contentVersionBlob) {
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.ContentLocation = 'S';
        contentVersion.Title = 'bulk_job_' + job.id + '.' + job.contentType;
        contentVersion.PathOnClient = 'bulk_job_' + job.id + '.' + job.contentType;
        insertContentVersion(log, contentVersion, contentVersionBlob);
    }

    public static void insertContentVersion(Log__c log, ContentVersion contentVersion, Blob contentVersionBlob) {
        if (isPassthroughMode()) {
            PassthroughtModeService.sendContentVersion(new ContentVersionWrapper(contentVersion, contentVersionBlob.toString()));
        } else {
            BroadcastService.sendContentVersion(log, new ContentVersionWrapper(contentVersion, contentVersionBlob.toString()));
            contentVersion.VersionData = contentVersionBlob;
            insert contentVersion;
        }
    }

    public static void createContentDocumentLinks(Set<String> setJobIds) {
        Set<String> setSearchStrings = new Set<String>();
        for (String jobId : setJobIds) {
            setSearchStrings.add('bulk_job_' + jobId + '%');
        }
        List<ContentVersion> lstContentVersions = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Title LIKE :setSearchStrings];
        if (!lstContentVersions.isEmpty()) {
            Set<String> setContentDocumentIds = new Set<String>();
            List<ContentDocumentLink> lstContentDocumentLinks = new List<ContentDocumentLink>();
            for (Log__c log : [SELECT Id, Async_Job_Id__c FROM Log__c WHERE Async_Job_Id__c IN :setJobIds]) {
                for (ContentVersion contentVersion : lstContentVersions) {
                    if (contentVersion.Title.contains(log.Async_Job_Id__c)) {
                        setContentDocumentIds.add(contentVersion.ContentDocumentId);
                        ContentDocumentLink contentDocumentLink = new ContentDocumentLink();
                        contentDocumentLink.LinkedEntityId = log.Id;
                        contentDocumentLink.ContentDocumentId = contentVersion.ContentDocumentId;
                        contentDocumentLink.ShareType = 'V';
                        lstContentDocumentLinks.add(contentDocumentLink);
                    }
                }
            }
            List<ContentDocumentLink> lstContentDocumentLinksExist = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId IN :setContentDocumentIds];
            List<ContentDocumentLink> lstContentDocumentLinksForInsert = new List<ContentDocumentLink>();
            for (ContentDocumentLink contentDocumentLink : lstContentDocumentLinks) {
                Boolean exist = false;
                for (ContentDocumentLink contentDocumentLinkExist : lstContentDocumentLinksExist) {
                    if (contentDocumentLink.ContentDocumentId == contentDocumentLinkExist.ContentDocumentId && contentDocumentLink.LinkedEntityId == contentDocumentLinkExist.LinkedEntityId) {
                        exist = true;
                        break;
                    }
                }
                if (!exist) {
                    lstContentDocumentLinksForInsert.add(contentDocumentLink);
                }
            }
            if (!lstContentDocumentLinksForInsert.isEmpty()) {
                insert lstContentDocumentLinksForInsert;
            }
        }
    }

    public static List<Log__c> getLogsLastWeek() {
        String query = new QBuilder(Log__c.SObjectType)
                .selectFields(new Set<String>{'Id', Log__c.Async_Job_Id__c.getDescribe().getName()})
                .add(QBuilder.condition(Log__c.Async_Job_Id__c.getDescribe().getName()).notEqualsTo(null))
                .add(QBuilder.condition(Log__c.Created_At__c.getDescribe().getName()).isGreaterOrEquals(System.now().addDays(BULK_LOGS_QUERY_WINDOW_DAYS)))
                .build();
        return (List<Log__c>)JSON.deserialize(JSON.serialize(runQuery(ConnectedOrgService.getPassthroughConnectedOrg(), query)), List<Log__c>.class);
    }

    public static List<Object> runQuery(Connected_Org__c corg, String q) {
        return isPassthroughMode() ? HttpUtils.runToolingQuery(corg.Instance_Url__c, ConnectedOrgService.getConnectedOrgAccessToken(corg), q) : Database.query(q);
    }

    public static List<String> rowSplitter(String row, String columnDelimiter) {
        List<String> lstRowParts = new List<String>();
        while (row != '') {
            Integer next = 0;
            if (row.startsWith('"')) {
                row = row.substring(1);
                Integer quoteIndex = findQuote(row, 0);
                next = quoteIndex + 1;
                lstRowParts.add(row.substring(0, quoteIndex).replace('""', '"'));
            } else {
                next = row.indexOf(columnDelimiter, next);
                if (next == -1) {
                    next = row.length();
                }
                lstRowParts.add(row.substring(0, next));
            }
            if (next == row.length() - 1) {
                lstRowParts.add('');
            }
            row = next < row.length() ? row.substring(next+1) : '';
        }
        if (lstRowParts.size() == 0) {
            lstRowParts.add('');
        }
        return lstRowParts;
    }

    public static Integer findQuote(String row, Integer skip) {
        Pattern quotePattern = Pattern.compile('(?<!")"(?!")');
        Matcher m = quotePattern.matcher(row);
        m.region(skip, m.regionEnd());
        if (!m.find()) {
            return -1;
        }
        return m.start();
    }

    public static String formatErrorMessage(String errorMessage) {
        return String.isBlank(errorMessage) ? errorMessage : errorMessage.replaceAll(ConfigUtil.REGEX_SOBJECT_ID, '').replaceAll(ConfigUtil.REGEX_DIGIT, '').abbreviate(255);
    }

    public class RowIterator implements Iterator<String>, Iterable<String> {

        private String fileData;
        private String rowDelimiter = '\n';
        private Integer index = 0;
        private Integer count = 0;

        public RowIterator(String fileData, String rowDelimiter) {
            this.fileData = fileData;
            this.rowDelimiter = rowDelimiter;
        }

        public Boolean hasNext() {
            return index < fileData.length() ? true : false;
        }

        public String next() {
            Integer key = fileData.indexOf(count == 0 ? rowDelimiter : '"' + rowDelimiter, index);
            if (count != 0 && key != -1) key++;
            if (key == -1) {
                key = fileData.length();
            }
            String row = fileData.substring(index, key);
            index = key + 1;
            count++;
            return row;
        }

        public Iterator<String> iterator() {
            return this;
        }

    }

    public class Job {
        public String id;
        public String apiVersion;
        public String contentType;
        public String jobType;
        public String columnDelimiter;
        public String lineEnding;
        public String obj;
        public String operation;
        public String createdById;
        public String systemModstamp;
        public Long numberRecordsFailed;
        public Long numberRecordsProcessed;
    }

    public class JobWithBatches {
        public Job job;
        public Set<String> setBatchIds;
        public JobWithBatches(Job job, Set<String> setBatchIds) {
            this.job = job;
            this.setBatchIds = setBatchIds;
        }
    }

    public class ContentVersionWrapper {
        public ContentVersion contentVersion;
        public String contentVersionData;
        public ContentVersionWrapper(ContentVersion contentVersion, String contentVersionData) {
            this.contentVersion = contentVersion;
            this.contentVersionData = contentVersionData;
        }
    }

    public class BulkAPIProperty {
        public String apiVersion;
        public Datetime validUntilDate;
    }

}