public with sharing class BulkAPIJobBatchScheduler implements Database.Batchable<JobsResponse>, Database.Stateful, Database.AllowsCallouts, Database.RaisesPlatformEvents, Schedulable {

    private static Connected_Org__c corg;
    private static String queryLocator = '/services/data/v52.0/jobs/ingest';
    private Set<String> setAsyncJobIds = new Set<String>();
    private Set<String> setJobIds = new Set<String>();
    private Set<String> SET_STATES = new Set<String>{'Closed', 'JobComplete'};

    public BulkAPIJobBatchScheduler() {}

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new BulkAPIJobBatchScheduler(), 1);
    }

    public Iterable<JobsResponse> start(Database.BatchableContext BC) {
        corg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId());
        if (corg == null) {
            System.abortJob(BC.getJobId());
        }
        for (Log__c log : BulkAPIJobBatchService.getLogsLastWeek()) {
            setAsyncJobIds.add(log.Async_Job_Id__c);
        }
        return new CustomIterable();
    }

    public void execute(Database.BatchableContext BC, List<JobsResponse> scope) {
        for (Job job : scope[0].records) {
            if (!setAsyncJobIds.contains(job.id) && SET_STATES.contains(job.state)) {
                setJobIds.add(job.id);
            }
        }
        if (!scope[0].done) {
            queryLocator = scope[0].nextRecordsUrl;
        }
    }

    public void finish(Database.BatchableContext BC) {
        if (!setJobIds.isEmpty()) {
            Database.executeBatch(new BulkAPIJobBatch(setJobIds), 1);
        }
    }

    public static JobsResponse getAllJobs() {
        String responseBody = HttpUtils.get(
                corg.Instance_Url__c + queryLocator,
                ConfigUtil.getSFRestAPIHeaders(ConnectedOrgService.getConnectedOrgAccessToken(corg)),
                200
        );
        return (BulkAPIJobBatchScheduler.JobsResponse)JSON.deserialize(responseBody, BulkAPIJobBatchScheduler.JobsResponse.class);
    }

    public class CustomIterable implements Iterable<JobsResponse> {
        public Iterator<JobsResponse> iterator() {
            return new CustomIterator();
        }
    }

    public class CustomIterator implements Iterator<JobsResponse> {

        private List<JobsResponse> lstJobsResponses;
        private Integer currentIndex;

        public CustomIterator() {
            lstJobsResponses = new List<JobsResponse>();
            currentIndex = 0;
        }

        public Boolean hasNext() {
            if (String.isNotBlank(queryLocator)) {
                JobsResponse jobsResponse = getAllJobs();
                lstJobsResponses.add(jobsResponse);
                queryLocator = jobsResponse.nextRecordsUrl;
                return true;
            } else {
                return false;
            }
        }

        public JobsResponse next() {
            currentIndex++;
            return lstJobsResponses[currentIndex - 1];
        }

    }

    public class JobsResponse {
        Boolean done;
        String nextRecordsUrl;
        List<Job> records;
    }

    private class Job {
        String id;
        String state;
    }

}