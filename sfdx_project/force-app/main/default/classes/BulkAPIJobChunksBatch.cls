public with sharing class BulkAPIJobChunksBatch implements Database.Batchable<String>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents {

    private Set<String> setJobWithBatchIds = new Set<String>();
    private Map<String, BulkAPIJobBatchService.Job> mapJobs = new Map<String, BulkAPIJobBatchService.Job>();
    private String batchId;
    private BulkAPIJobBatchService.Job job;
    private Connected_Org__c corg;

    private String urlBatchRequest = '/services/async/{1}/job/{0}/batch/{2}/request';
    private String urlBatchResult = '/services/async/{1}/job/{0}/batch/{2}/result';
    private String urlJobFailedResults = '/services/data/v52.0/jobs/ingest/{0}/failedResults';

    private Blob contentVersionBlob;
    private Set<String> setErrors = new Set<String>();
    private static Map<Integer, String> mapErrors = new Map<Integer, String>();

    private List<Log__c> lstLogs = new List<Log__c>();

    public BulkAPIJobChunksBatch(List<BulkAPIJobBatchService.JobWithBatches> lstJobWithBatches) {
        for (BulkAPIJobBatchService.JobWithBatches jobWithBatches : lstJobWithBatches) {
            mapJobs.put(jobWithBatches.job.id, jobWithBatches.job);
            if (jobWithBatches.setBatchIds != null) {
                for (String batchId : jobWithBatches.setBatchIds) {
                    setJobWithBatchIds.add(jobWithBatches.job.id + '_' + batchId);
                }
            } else {
                setJobWithBatchIds.add(jobWithBatches.job.id + '_');
            }
        }
        corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId());
    }

    public Iterable<String> start(Database.BatchableContext BC) {
        List<String> lstJobWithBatchIds = new List<String>(setJobWithBatchIds);
        lstJobWithBatchIds.sort();
        return lstJobWithBatchIds;
    }

    public void execute(Database.BatchableContext BC, List<String> scope) {
        if (corg != null) {
            for (String jobWithBatchId : scope) {
                setJobWithBatchIds.remove(jobWithBatchId);
                job = mapJobs.get(jobWithBatchId.split('_')[0]);
                if (jobWithBatchId.split('_').size() > 1) {
                    batchId = jobWithBatchId.split('_')[1];
                    if (job.contentType == 'XML') {
                        parseResultXml();
                        parseRequestXml();
                    } else if (job.contentType == 'JSON') {
                        parseResultJSON();
                        parseRequestJSON();
                    } else if (job.contentType == 'CSV') {
                        parseResultCSV();
                        parseRequestCSV();
                    }
                } else {
                    getJobFailedRecordResults();
                }
            }
            if (contentVersionBlob != null && (contentVersionBlob.size() >= 2000000 || !JSON.serialize(setJobWithBatchIds).contains(job.id))) {
                BulkAPIJobBatchService.createContentVersion(BulkAPIJobBatchService.createLog(corg, job, setErrors), job, contentVersionBlob);
                contentVersionBlob = null;
            }
            if (!JSON.serialize(setJobWithBatchIds).contains(job.id)) {
                lstLogs.add(BulkAPIJobBatchService.createLog(corg, job, setErrors));
                setErrors = new Set<String>();
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        BulkAPIJobBatchService.insertLog(lstLogs);
    }

    private void getJobFailedRecordResults() {
        String responseBody = HttpUtils.get(
                corg.Instance_Url__c + String.format(urlJobFailedResults, new List<String>{job.id}),
                ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(corg)),
                200
        );
        Integer counter = 0;
        String rowDelimiter = String.isNotBlank(job.lineEnding) && BulkAPIJobBatchService.MAP_LINE_ENDINGS.containsKey(job.lineEnding) ? BulkAPIJobBatchService.MAP_LINE_ENDINGS.get(job.lineEnding) : '\n';
        String columnDelimiter = String.isNotBlank(job.columnDelimiter) && BulkAPIJobBatchService.MAP_DELIMITERS.containsKey(job.columnDelimiter) ? BulkAPIJobBatchService.MAP_DELIMITERS.get(job.columnDelimiter) : ',';
        BulkAPIJobBatchService.RowIterator rowIterator = new BulkAPIJobBatchService.RowIterator(responseBody,rowDelimiter);
        while (rowIterator.hasNext()) {
            String row = rowIterator.next();
            if (counter != 0) {
                List<String> lstRowParts = BulkAPIJobBatchService.rowSplitter(row, columnDelimiter);
                if (lstRowParts.size() > 1 && lstRowParts[1] != null && String.isNotBlank(lstRowParts[1])) {
                    setErrors.add(BulkAPIJobBatchService.formatErrorMessage(lstRowParts[1]));
                }
            }
            counter++;
        }
        rowIterator = null;
        contentVersionBlob = Blob.valueOf(responseBody);
    }

    private String getBatchResult() {
        return HttpUtils.get(
                corg.Instance_Url__c + String.format(urlBatchResult, new List<String>{job.id, job.apiVersion, batchId}),
                new Map<String, String>{'X-SFDC-Session' => UserInfo.getSessionId()},
                200
        );
    }

    private String getBatchRequest() {
        return HttpUtils.get(
                corg.Instance_Url__c + String.format(urlBatchRequest, new List<String>{job.id, job.apiVersion, batchId}),
                new Map<String, String>{'X-SFDC-Session' => UserInfo.getSessionId()},
                200
        );
    }

    private void parseResultXml() {
        Dom.Document resultDocument = new Dom.Document();
        resultDocument.load(getBatchResult());
        String xmlns = resultDocument.getRootElement().getNamespace();
        Integer counter = 0;
        for (Dom.XmlNode sObjectElement : resultDocument.getRootElement().getChildElements()) {
            if (sObjectElement.getChildElement('errors', xmlns) != null) {
                Dom.Document errorDocument = new Dom.Document();
                errorDocument.createRootElement('errors', xmlns, null);
                for (Dom.XmlNode errorElement : sObjectElement.getChildElement('errors', xmlns).getChildElements()) {
                    errorDocument.getRootElement().addChildElement(errorElement.getName(), errorElement.getNamespace(), null).addTextNode(errorElement.getText());
                }
                mapErrors.put(counter, errorDocument.toXmlString());
                String statusCode = errorDocument.getRootElement().getChildElement('statusCode', xmlns) != null ? errorDocument.getRootElement().getChildElement('statusCode', xmlns).getText() : '';
                String message = errorDocument.getRootElement().getChildElement('message', xmlns) != null ? errorDocument.getRootElement().getChildElement('message', xmlns).getText() : '';
                setErrors.add(BulkAPIJobBatchService.formatErrorMessage((statusCode + ':' + message)));
            }
            counter++;
        }
    }

    private void parseRequestXml() {
        Dom.Document requestDocument = new Dom.Document();
        requestDocument.load(getBatchRequest());
        Dom.Document newDocument = new Dom.Document();
        if (contentVersionBlob != null) {
            newDocument.load(contentVersionBlob.toString());
        } else {
            Dom.XmlNode newRootElement = newDocument.createRootElement('sObjects', null, null);
            newRootElement.setNamespace('', requestDocument.getRootElement().getNamespace());
        }
        Integer counter = 0;
        for (Dom.XmlNode sObjectElement : requestDocument.getRootElement().getChildElements()) {
            if (mapErrors.containsKey(counter)) {
                Dom.XmlNode newSObjectElement = newDocument.getRootElement().addChildElement('sObject', null, null);
                for (Dom.XmlNode sObjectFieldElement : sObjectElement.getChildElements()) {
                    newSObjectElement.addChildElement(sObjectFieldElement.getName(), null, null).addTextNode(sObjectFieldElement.getText());
                }
                Dom.Document errorDocument = new Dom.Document();
                errorDocument.load(mapErrors.get(counter));
                Dom.XmlNode newErrorsElement = newSObjectElement.addChildElement('errors', null, null);
                for (Dom.XmlNode errorElement : errorDocument.getRootElement().getChildElements()) {
                    newErrorsElement.addChildElement(errorElement.getName(), errorElement.getNamespace(), null).addTextNode(errorElement.getText());
                }
            }
            counter++;
        }
        contentVersionBlob = Blob.valueOf(newDocument.toXmlString());
    }

    private void parseResultJSON() {
        Integer counter = 0;
        for (Object obj : (List<Object>)JSON.deserializeUntyped(getBatchResult())) {
            if (((Map<String, Object>)obj).containsKey('errors')) {
                mapErrors.put(counter, JSON.serialize(((Map<String, Object>)obj).get('errors')));
                ErrorJSON errorJSON = (ErrorJSON)JSON.deserialize(JSON.serialize(obj), ErrorJSON.class);
                setErrors.add(BulkAPIJobBatchService.formatErrorMessage((errorJSON.statusCode + ':' + errorJSON.message)));
            }
            counter++;
        }
    }

    private void parseRequestJSON() {
        List<Object> lstErrors = new List<Object>();
        if (contentVersionBlob != null) {
            lstErrors = (List<Object>)JSON.deserializeUntyped(contentVersionBlob.toString());
        }
        Integer counter = 0;
        for (Object obj : (List<Object>)JSON.deserializeUntyped(getBatchRequest())) {
            if (mapErrors.containsKey(counter)) {
                ((Map<String, Object>)obj).put('errors', (List<Object>)JSON.deserializeUntyped(mapErrors.get(counter)));
                lstErrors.add(obj);
            }
            counter++;
        }
        contentVersionBlob = Blob.valueOf(JSON.serialize(lstErrors));
    }

    private void parseResultCSV() {
        Integer counter = 0;
        String rowDelimiter = String.isNotBlank(job.lineEnding) && BulkAPIJobBatchService.MAP_LINE_ENDINGS.containsKey(job.lineEnding) ? BulkAPIJobBatchService.MAP_LINE_ENDINGS.get(job.lineEnding) : '\n';
        String columnDelimiter = String.isNotBlank(job.columnDelimiter) && BulkAPIJobBatchService.MAP_DELIMITERS.containsKey(job.columnDelimiter) ? BulkAPIJobBatchService.MAP_DELIMITERS.get(job.columnDelimiter) : ',';
        BulkAPIJobBatchService.RowIterator rowIterator = new BulkAPIJobBatchService.RowIterator(getBatchResult(),rowDelimiter);
        while (rowIterator.hasNext()) {
            String row = rowIterator.next();
            if (counter != 0) {
                List<String> lstRowParts = BulkAPIJobBatchService.rowSplitter(row, columnDelimiter);
                if (lstRowParts.size() > 3 && lstRowParts[3] != null && String.isNotBlank(lstRowParts[3])) {
                    mapErrors.put(counter, lstRowParts[3]);
                    setErrors.add(BulkAPIJobBatchService.formatErrorMessage(lstRowParts[3]));
                }
            }
            counter++;
        }
    }

    private void parseRequestCSV() {
        List<String> lstErrors = new List<String>();
        if (contentVersionBlob != null) {
            BulkAPIJobBatchService.RowIterator rowIterator = new BulkAPIJobBatchService.RowIterator(contentVersionBlob.toString(),'\n');
            while (rowIterator.hasNext()) {
                lstErrors.add(rowIterator.next());
            }
        }
        Integer counter = 0;
        String rowDelimiter = String.isNotBlank(job.lineEnding) && BulkAPIJobBatchService.MAP_LINE_ENDINGS.containsKey(job.lineEnding) ? BulkAPIJobBatchService.MAP_LINE_ENDINGS.get(job.lineEnding) : '\n';
        BulkAPIJobBatchService.RowIterator rowIterator = new BulkAPIJobBatchService.RowIterator(getBatchRequest(),rowDelimiter);
        while (rowIterator.hasNext()) {
            String line = rowIterator.next();
            if (counter == 0 && lstErrors.isEmpty()) {
                lstErrors.add('sf__Error,' + line);
            } else if (mapErrors.containsKey(counter)) {
                lstErrors.add('"' + mapErrors.get(counter) + '",' + line);
            }
            counter++;
        }
        contentVersionBlob = Blob.valueOf(String.join(lstErrors, '\n'));
    }

    private class ErrorJSON {
        String statusCode;
        String message;
    }

}