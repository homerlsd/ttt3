public with sharing class AdminController {

    public Boolean isDev { get; set; }
    public String packageNamespace { get {return Configutil.getNameSpacePrefix();} set; }

    public static String baseUrl {
        get {return System.URL.getOrgDomainUrl().toExternalForm();}
        set;
    }

    public static String salesforceBaseUrl {
        get {return System.URL.getSalesforceBaseUrl().toExternalForm();}
        set;
    }

    public static String baseRemoteSiteSettings {
        get {return JSON.serialize(AdminService.defaultRemoteSiteSettings);}
        set;
    }

    public static String remoteSiteSettingsPayload {
        get {
            StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :ConfigUtil.METADATA_REMOTE_SITE_PAYLOAD_RESOURCE_NAME LIMIT 1];
            return sr.Body.toString();
        }
        set;
    }

    public static Id getOrgId() {
        return UserInfo.getOrganizationId();
    }

    public AdminController() {
        String isDevParam = ApexPages.currentPage().getParameters().get('dev');
        if (String.isNotBlank(isDevParam)) {
            Cookie devCookie = new Cookie('a2developmentMode', isDevParam, null, -1, false);
            ApexPages.currentPage().setCookies(new Cookie[]{ devCookie });
            isDev = Boolean.valueOf(isDevParam);
        } else {
            Cookie devCookie = ApexPages.currentPage().getCookies().get('a2developmentMode');
            isDev = devCookie != null ? Boolean.valueOf(devCookie.getValue()) : false;
        }
    }

    @RemoteAction
    public static String remoteActionHandler(String input) {
        String result;
        RemoteActionResponse response = new RemoteActionResponse();
        String methodName;

        try {
            Map<String, Object> request = (Map<String, Object> )JSON.deserializeUntyped(input);
            response.params = request;

            String method = (String)request.get('method');
            methodName = method;
            Object data = request.get('data');

            if (method == 'getEmailServiceData') {
                response.data = AdminService.getEmailServiceData();
            } else if (method == 'createEmailService') {
                response.data = AdminService.createEmailService(data);
            } else if (method == 'confirmEmailService') {
                response.data = AdminService.confirmEmailService(data);
            } else if (method == 'getConfigurationOverviewData') {
                response.data = AdminService.getConfigurationOverviewData();
            } else if (method == 'getJiraSettings') {
                response.data = AdminService.getJiraSettings();
            } else if (method == 'resetTimerForNewConnectedApp') {
                response.data = AdminService.resetTimerForNewConnectedApp();
            } else if (method == 'deleteConnectedOrg') {
                response.data = AdminService.deleteConnectedOrg(data);
            } else if (method == 'deleteFakeConnectedOrg') {
                response.data = AdminService.deleteFakeConnectedOrg();
            } else if (method == 'saveJiraSettings') {
                response.data = AdminService.saveJiraSettings(data);
            } else if (method == 'saveJiraSettings2') {
                response.data = AdminService.saveJiraSettings2(data);
            } else if (method == 'resetJiraSettings') {
                response.data = AdminService.resetJiraSettings();
            } else if (method == 'getJiraProjectUsers') {
                response.data = AdminService.getJiraProjectUsers(String.valueOf(data));
            } else if (method == 'saveConnecterAppDetails') {
                response.data = AdminService.saveConnecterAppDetails(data);
            } else if (method == 'createConnectedApp') {
                response.data = AdminService.createConnectedApp(data);
            } else if (method == 'getLogAccessData') {
                response.data = AdminService.getLogAccessData();
            } else if (method == 'getLogAccessUsers') {
                response.data = AdminService.getLogAccessUsers();
            } else if (method == 'addPermissionSetToUser') {
                response.data = AdminService.addPermissionSetToUser(data);
            } else if (method == 'removePermissionSetAssignment') {
                response.data = AdminService.removePermissionSetAssignment(data);
            } else if (method == 'getMasks') {
                response.data = AdminService.getMasks();
            } else if (method == 'saveMask') {
                response.data = AdminService.saveMask(data);
            } else if (method == 'deleteMask') {
                response.data = AdminService.deleteMask(data);
            } else if (method == 'testMask') {
                response.data = AdminService.testMask(data);
            } else if (method == 'manageServiceScheduler') {
                response.data = AdminService.manageServiceScheduler(data);
            } else if (method == 'getLoggerWrapperInfo') {
                response.data = AdminService.getLoggerWrapperInfo();
            } else if (method == 'getSplunkSettings') {
                response.data = AdminService.getSplunkSettings();
            } else if (method == 'generateSplunkToken') {
                response.data = AdminService.generateSplunkToken(data);
            } else if (method == 'saveSplunkSettings') {
                response.data = AdminService.saveSplunkSettings(data);
            } else if (method == 'setSplunkSettings') {
                response.data = AdminService.setSplunkSettings(data);
            } else if (method == 'sendMessageToSplunk') {
                response.data = AdminService.sendMessageToSplunk(data);
            } else if (method == 'validateSplunkEventCollectorConnection') {
                response.data = AdminService.validateSplunkEventCollectorConnection(data);
            } else if (method == 'getCreateMeta') {
                response.data = AdminService.getCreateMeta(data);
            } else if (method == 'getConnectedOrgsInfo') {
                response.data = AdminService.getConnectedOrgsInfo();
            } else if (method == 'updatePassthroughtMode') {
                response.data = AdminService.updatePassthroughtMode(data);
            } else if (method == 'createConnectionOrg') {
                response.data = AdminService.createConnectionOrg(data);
            } else if (method == 'updateConnectedOrg') {
                response.data = AdminService.updateConnectedOrg(data);
            } else if (method == 'refreshConnectedOrgToken') {
                response.data = AdminService.refreshConnectedOrgToken(data);
            } else if (method == 'testConnectedOrg') {
                response.data = AdminService.testConnectedOrg(data);
            } else if (method == 'saveJiraFieldsMapping') {
                response.data = AdminService.saveJiraFieldsMapping(data);
            } else if (method == 'getCustomSettings') {
                response.data = AdminService.getCustomSettings();
            } else if (method == 'saveCustomSettings') {
                response.data = AdminService.saveCustomSettings(data);
            } else if (method == 'getSlackSettings') {
                response.data = AdminService.getSlackSettings();
            } else if (method == 'getSlackChannels') {
                response.data = AdminService.getSlackChannels();
            } else if (method == 'saveSlackSettings') {
                response.data = AdminService.saveSlackSettings(data);
            } else if (method == 'getMonitoringSettings') {
                response.data = AdminService.getMonitoringSettings(data);
            } else if (method == 'setMonitoringSetting') {
                response.data = AdminService.setMonitoringSetting(data);
            } else if (method == 'setBatchErrorTrackingSetting') {
                response.data = AdminService.setBatchErrorTrackingSetting(data);
            } else if (method == 'getBatchErrorTrackingSetting') {
                response.data = AdminService.getBatchErrorTrackingSetting(data);
            } else if (method == 'setMonitoringRule') {
                response.data = AdminService.setMonitoringRule(data);
            } else if (method == 'setNotificationRules') {
                response.data = AdminService.setNotificationRules(data);
            } else if (method == 'getPagerDutySettings') {
                response.data = AdminService.getPagerDutySettings();
            } else if (method == 'getPagerDutyServices') {
                response.data = AdminService.getPagerDutyServices();
            } else if (method == 'savePagerDutySettings') {
                response.data = AdminService.savePagerDutySettings(data);
            } else if (method == 'getLogCategories') {
                response.data = AdminService.getLogCategories();
            } else if (method == 'setLogRecordTypeMappings') {
                response.data = AdminService.setLogRecordTypeMappings(data);
            } else if (method == 'deleteLogRecordTypeMappings') {
                response.data = AdminService.deleteLogRecordTypeMappings(data);
            } else if (method == 'deleteMonitoringRule') {
                response.data = AdminService.deleteMonitoringRule(data);
            } else if (method == 'getActionRules') {
                response.data = AdminService.getActionRules(data);
            } else if (method == 'setArchivalSetting') {
                response.data = AdminService.setArchivalSetting(data);
            } else if (method == 'getArchivalSettings') {
                response.data = AdminService.getArchivalSettings(data);
            } else if (method == 'setArchivalRule') {
                response.data = AdminService.setArchivalRule(data);
            } else if (method == 'setJiraSetting') {
                response.data = AdminService.setJiraSetting(data);
            } else if (method == 'getJiraRuleSettings') {
                response.data = AdminService.getJiraDataSettings(data);
            } else if (method == 'setJiraRule') {
                response.data = AdminService.setJiraRule(data);
            } else if (method == 'getDefaultNotificationTemplate') {
                response.data = ConfigUtil.DEFAULT_ACTION_TEMPLATE;
            } else if (method == 'getDefaultSlackActionTemplate') {
                response.data = AdminService.getDefaultSlackActionTemplate();
            } else if (method == 'getDefaultJiraActionTemplate') {
                response.data = AdminService.getDefaultJiraActionTemplate();
            } else if (method == 'deleteNotificationRule') {
                response.data = AdminService.deleteNotificationRule(data);
            } else if (method == 'getOccurrenceLogs') {
                response.data = AdminService.getOccurrenceLogs(data);
            } else if (method == 'getAppPermissions') {
                response.data = AdminService.getAppPermissions(data);
            } else if (method == 'getInstalledVersion') {
                response.data = AdminService.getInstalledVersion();
            } else if (method == 'flowErrorTracking') {
                response.data = AdminService.flowErrorTracking(data);
            } else if (method == 'emailToCaseTracking') {
                response.data = AdminService.emailToCaseTracking(data);
            } else if (method == 'setupRemoteSiteSettings') {
                response.data = AdminService.setupRemoteSiteSettings();
            } else if (method == 'getMergeFields') {
                response.data = AdminService.getMergeFields();
            } else if (method == 'getRemoteSiteSettings') {
                response.data = AdminService.getRemoteSiteSettings();
            } else if (method == 'getSelfConnectedOrgsInfo') {
                response.data = AdminService.getSelfConnectedOrgsInfo();
            } else if (method == 'startTestExceptionEmail') {
                response.data = TestDataGenerator.sendTestEmailException();
            } else if (method == 'getTestEmailExceptionLog') {
                response.data = TestDataGenerator.getTestEmailExceptionLog();
            } else if (method == 'startJiraRuleTest') {
                response.data = TestDataGenerator.startJiraRuleTest();
            } else if (method == 'getTestJiraRuleLog') {
                response.data = TestDataGenerator.getTestJiraRuleLog();
            } else if (method == 'startSlackIntegrationTest') {
                response.data = TestDataGenerator.startSlackIntegrationTest();
            } else if (method == 'getSlackIntegrationTestLog') {
                response.data = TestDataGenerator.getTestSlackRuleLog();
            } else if (method == 'startPlatformEventTest') {
                response.data = TestDataGenerator.startPlatformEventTest();
            } else if (method == 'platformEventTestSendMeAnEmail') {
                response.data = TestDataGenerator.platformEventTestSendMeAnEmail();
            } else if (method == 'getPlatformEventTestLog') {
                response.data = TestDataGenerator.getPlatformEventTestLog();
            } else if (method == 'createMonitoringSpikeRule') {
                response.data = TestDataGenerator.createMonitoringSpikeRule(data);
            } else if (method == 'createMonitoringImpactRule') {
                response.data = TestDataGenerator.createMonitoringImpactRule(data);
            } else if (method == 'startMonitoringRuleTest') {
                response.data = TestDataGenerator.startMonitoringRuleTest();
            } else if (method == 'getTestMonitoringSpikeRuleLog') {
                response.data = TestDataGenerator.getTestMonitoringSpikeRuleLog();
            } else if (method == 'getTestMonitoringImpactRuleLog') {
                response.data = TestDataGenerator.getTestMonitoringImpactRuleLog();
            } else if (method == 'getExistMonitoringRules') {
                response.data = TestDataGenerator.getExistMonitoringRules();
            } else if (method == 'getQuickStartState') {
                response.data = AdminService.getQuickStartState();
            } else if (method == 'setQuickStartState') {
                response.data = AdminService.setQuickStartState(data);
            } else if (method == 'getUserInfo') {
                response.data = AdminService.getUserInfo();
            } else if (method == 'monitoringTestSendMeAnEmail') {
                response.data = TestDataGenerator.monitoringTestSendMeAnEmail();
            } else if (method == 'connectedAppSendMeAnEmail') {
                response.data = TestDataGenerator.connectedAppSendMeAnEmail();
            } else if (method == 'testEmailExceptionSendMeAnEmail') {
                response.data = TestDataGenerator.testEmailExceptionSendMeAnEmail();
            } else if (method == 'getApexEmailNotification') {
                response.data = AdminService.getApexEmailNotification();
            } else if (method == 'getPackageEmailServiceFunctionEmailAddress') {
                response.data = AdminService.getPackageEmailServiceFunctionEmailAddress();
            } else if (method == 'getQSAnotherConnectedOrg') {
                response.data = ConnectedOrgService.getQSAnotherConnectedOrg();
            } else if (method == 'isMyDomainEnabled') {
                response.data = AdminService.isMyDomainEnabled();
            } else if (method == 'createSelfConnectionOrg') {
                response.data = AdminService.createSelfConnectionOrg(data);
            } else if (method == 'getQSAnotherConnectedOrg') {
                response.data = ConnectedOrgService.getQSAnotherConnectedOrg();
            } else if (method == 'getUrlToPlatformEventSubscriberConfig') {
                response.data = AdminService.getUrlToPlatformEventSubscriberConfig();
            } else if (method == 'getAdminActiveUsers') {
                response.data = AdminService.getAdminActiveUsers();
            } else if (method == 'setPlatformEventSubscriberConfig') {
                response.data = AdminService.setPlatformEventSubscriberConfig(String.valueOf(data));
            } else if (method == 'getPlatformEventSubscriberConfig') {
                response.data = AdminService.getPlatformEventSubscriberConfig();
            } else if (method == 'setRuleIndex') {
                response.data = AdminService.setRuleIndex(data);
            } else if (method == 'getNotificationSettings') {
                response.data = AdminService.getNotificationSettings(data);
            } else if (method == 'setNotificationRule') {
                response.data = AdminService.setNotificationRule(data);
            } else if (method == 'getBroadcastSettings') {
                response.data = AdminService.getBroadcastSettings(data);
            } else if (method == 'setBroadcastRule') {
                response.data = AdminService.setBroadcastRule(data);
            } else if (method == 'getScheduleBulkAPIBatch') {
                response.data = AdminService.getScheduleBulkAPIBatch();
            }  else if (method == 'abortScheduleBulkAPIBatch') {
                response.data = AdminService.abortScheduleBulkAPIBatch();
            }  else if (method == 'scheduleBulkAPIBatch') {
                response.data = AdminService.scheduleBulkAPIBatch(data);
            } else if (method == 'resetAllSettingsForRefreshSandbox') {
                response.data = AdminService.resetAllSettingsForRefreshSandbox();
            } else if (method == 'getSubscriptionInfo') {
                response.data = AdminService.getSubscriptionInfo();
            } else if (method == 'checkEmailAccess') {
                response.data = AdminService.checkEmailAccess();
            } else if (method == 'getTeamChannels') {
                response.data = AdminService.getTeamChannels(String.valueOf(data));
            } else if (method == 'getTeams') {
                response.data = AdminService.getTeams();
            } else if (method == 'getTeamsSettings') {
                response.data = AdminService.getTeamsSettings();
            } else if (method == 'setTeamsSettings') {
                response.data = AdminService.setTeamsSettings(data);
            } else if (method == 'getGitHubRepos') {
                response.data = GitHubUtils.getReposInfos();
            } else if (method == 'getGitHubRepoBranches') {
                response.data = GitHubUtils.getRepoBranchesInfos(String.valueOf(data));
            } else if (method == 'setGitHubSettings') {
                response.data = AdminService.setGitHubSettings(data);
            } else if (method == 'getGitHubSettings') {
                response.data = AdminService.getGitHubSettings();
            } else if (method == 'resetGitHubSettings') {
                response.data = AdminService.resetGitHubSettings();
            } else if(method == 'startTeamsIntegrationTest') {
                response.data = TestDataGenerator.startTeamsIntegrationTest();
            } else if (method == 'setChangeTrackingSettings') {
                response.data = AdminService.setChangeTrackingSettings(data);
            } else if (method == 'getChangeTrackingSettings') {
                response.data = AdminService.getChangeTrackingSettings();
            } else if (method == 'getTeamsIntegrationTestLog') {
                response.data = TestDataGenerator.getTestTeamsRuleLog();
            } else if (method == 'getDefaultTeamsActionTemplate') {
                response.data = AdminService.getDefaultTeamsActionTemplate();
            } else if (method == 'validateAndRefreshGraphApiOauthToken') {
                response.data = GraphAPIService.validateAndRefreshGraphApiOauthToken();
            } else {
                response.error = 'Action not found';
            }
            result = JSON.serialize(response);
        }
        catch(Exception e) {
            response.error = e.getMessage();
            response.stack = e.getStackTraceString();
            Logger.getInstance().internalError(e, AdminController.class.getName(), 'remoteActionHandler' + (String.isNotBlank(methodName) ? '.' + methodName : ''));
        }
        finally {
            try {
                result = JSON.serialize(response);
            }
            catch(Exception e) {
                Logger.getInstance().internalError(e, AdminController.class.getName(), 'remoteActionHandler.serializeResponse');
            }
        }

        return result;
    }

    public class RemoteActionResponse {
        public Object params;
        public Object data;
        public String error;
        public String stack;
    }
}