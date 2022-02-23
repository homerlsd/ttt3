public with sharing class LogServiceScheduler implements Schedulable, Database.AllowsCallouts {
    public void execute(SchedulableContext sc) {
        if (ConfigUtil.SETTINGS.Service_Scheduler_Enabled__c) {
            Database.executeBatch(new LogServiceBatch(), 1);
            if (ConfigUtil.SETTINGS.Batch_Error_Tracking_Enabled__c) {
                Database.executeBatch(new JobBatch());
            }
            Database.executeBatch(new MetricsBatch());

            // check and fix support settings for email-to-case
            AdminService.checkEmailToCaseErrorTrackingSettings();

            // refresh Jira OAuth Token and Refresh Token
            JiraService.validateAndRefreshJiraOauthTokenFuture();

            // validate Graph Api OAuth token and refresh
            GraphAPIService.validateAndRefreshGraphApiOauthTokenFuture();

            // check and start tracking changes
            GitHubUtils.startGitHubCommitBatch();
        }
    }
}