public without sharing class AdminService {

    public static User getUserInfo() {
        User user = new User();
        user.FirstName = UserInfo.getFirstName();
        user.LastName = UserInfo.getLastName();
        user.Email = UserInfo.getUserEmail();
        user.CompanyName = UserInfo.getOrganizationName();
        return user;
    }

    public static Map<String, Boolean> isMyDomainEnabled() {
        Map<String, Boolean> output = new Map<String, Boolean>();
        Boolean enabled = URL.getSalesforceBaseUrl().getHost().endsWith(ConfigUtil.SALESFORCE_DOMAIN) || URL.getSalesforceBaseUrl().getHost().contains(ConfigUtil.CUSTOM_DOMAIN_SYMBOLS);
        output.put('enabled', enabled);
        return output;
    }

    public static String getUrlToPlatformEventSubscriberConfig() {
        String triggerID = platformEventSubscriberTriggerId;
        return ConfigUtil.PLATFORM_EVENT_SUBSCRIPTION_CONFIG_URL + '?subscriptionName=' + triggerID.left(15) + '&topicApiName=' +ConfigUtil.getNameSpacePrefix() + 'Log_Event__e';
    }

    public static List<User> getAdminActiveUsers() {
        return [
            Select Id, Name, Profile.UserLicense.LicenseDefinitionKey
            From User
            Where IsActive = true AND Profile.UserLicense.LicenseDefinitionKey = 'SFDC'
        ];
    }

    public static List<MergeField> addCustomMergeFields(Schema.DescribeSObjectResult d, String dType) {
        List<MergeField> result = new List<MergeField>();
        String label =  d.getLabel() + ' Link';
        String apiName = '{!' + d.getName() + '.Link}';
        result.add(new MergeField(label, apiName, dType, 'link'));
        return result;
    }

    public static List<MergeField> getSobjectFields(Schema.DescribeSObjectResult d, String dType) {
        return getSobjectFields(d, dType, null, null);
    }

    public static Boolean isStandardPreferencesField(Schema.DescribeFieldResult dfr) {
        if(dfr != null && !dfr.isCustom() && (dfr.getLocalName().startsWith('UserPreferences') || dfr.getLocalName().startsWith('EmailPreferences'))) {
            return true;
        }
        return false;
    }

    public static Map<String, String> getDefaultJiraActionTemplate() {
        Map<String, String> resp = new Map<String, String>{};
        String subjectTemplate = 'New Error in  \'{!\'{0}.{1}\'}\' : \'{!\'{0}.{2}\'}\'';
        String subject = String.format(subjectTemplate,
		new List<String> {
			Schema.sObjectType.Log__c.getName(),
			Schema.sObjectType.Log__c.fields.Organization_Name__c.getName(),
			Schema.sObjectType.Log__c.fields.Summary__c.getName()
		});


        String bodyTemplate = '\'{\'!{0}.Link\'}\'\nCategory: \'{\'!{0}.{1}\'}\'\nType: \'{\'!{0}.{2}\'}\'\nArea: \'{\'!{0}.{3}\'}\' \'{\'!{0}.{4}\'}\'';
        String body = String.format(bodyTemplate,
            new List<String> { 
                Schema.sObjectType.Log__c.getName(),
                Schema.sObjectType.Log__c.fields.Category__c.getName(),
                Schema.sObjectType.Log__c.fields.Type__c.getName(),
                Schema.sObjectType.Log__c.fields.Area__c.getName(),
                Schema.sObjectType.Log__c.fields.Details__c.getName()
            }
        );
        resp.put('subject', subject);
        resp.put('body', body);
        return resp;
    }

    public static Map<String, String> getDefaultSlackActionTemplate() {
        return getDefaultNotificationsTemplate();
    }

    public static Map<String, String> getDefaultTeamsActionTemplate() {
        return getDefaultNotificationsTemplate();
    }

    public static Map<String, String> getDefaultNotificationsTemplate() {
        Map<String, String> resp = new Map<String, String>{};
        String subject = 'New Log {!' +  Schema.sObjectType.Log__c.getName() + '.Link} in {!' + Schema.sObjectType.Log__c.getName() + '.'
            + Schema.sObjectType.Log__c.fields.Organization_Name__c.getName() + '}';
        String body = '{!' + Schema.sObjectType.Log__c.getName() + '.' + Schema.sObjectType.Log__c.fields.Category__c.getName() + '} : {!'
            + Schema.sObjectType.Log__c.getName() + '.' + Schema.sObjectType.Log__c.fields.Type__c.getName() + '} \n {!' + Schema.sObjectType.Log__c.getName()
            + '.' + Schema.sObjectType.Log__c.fields.Summary__c.getName() + '} \n {!' + Schema.sObjectType.Log__c.getName() + '.Link}';
        resp.put('subject', subject);
        resp.put('body', body);
        return resp;
    }

    public static List<MergeField> getSobjectFields(Schema.DescribeSObjectResult d, String dType, Schema.DescribeFieldResult parent, Schema.DescribeSObjectResult parentObject) {
        List<MergeField> result = new List<MergeField>();
        Map<String, Schema.SObjectField> fieldsMap = d.fields.getMap();
        for(String sobjectFieldName : fieldsMap.keySet()) {
            if(ConfigUtil.MERGE_FIELDS_SKIP_FIELD_NAMES.contains(sobjectFieldName)) continue;

            Schema.SObjectField sfd = fieldsMap.get(sobjectFieldName);
            Schema.DescribeFieldResult dfr = sfd.getDescribe();
            if(isStandardPreferencesField(dfr)) continue;
            String label = ((parent != null) ? (parent.getLabel() + ' -> ') : '') + dfr.getLabel();
            String localName = (parent != null) ? (parent.getRelationshipName() + '.' + dfr.getName()) : dfr.getName();
            String objectName = (parentObject != null) ? parentObject.getName() : d.getName();
            String apiName = '{!' + objectName + '.' + localName + '}';
            String sobjectFieldAPIName = (parentObject != null) ? parent.getRelationshipName() + sobjectFieldName : sobjectFieldName;

            result.add(new MergeField(label, apiName, dType, sobjectFieldAPIName));

            List<Schema.sObjectType> relSObjectTypes = dfr.getReferenceTo();
            if(!relSObjectTypes.isEmpty() && parent == null && dfr.getRelationshipName() != null) {
                Schema.DescribeSObjectResult relObjectDescr = relSObjectTypes.get(0).getDescribe();
                result.addAll(getSobjectFields(relObjectDescr, dType, dfr, d));
            }
        }
        return result;
    }

    public static Object getMergeFields() {
        List<MergeField> mergeFields = new List<MergeField>();

        Schema.DescribeSObjectResult logDsR = Log__c.sObjectType.getDescribe();
        mergeFields.addAll(addCustomMergeFields(logDsR, 'log'));
        mergeFields.addAll(getSobjectFields(logDsR, 'log'));

        Schema.DescribeSObjectResult eventDsR = Event__c.sObjectType.getDescribe();
        mergeFields.addAll(addCustomMergeFields(eventDsR, 'event'));
        mergeFields.addAll(getSobjectFields(eventDsR, 'event'));

        mergeFields.sort();
        return mergeFields;
    }

    public class MergeField implements Comparable{
        public String label;
        public String value;
        public String sobjectype;
        public String apiName;

        public MergeField(String label, String value, String sobjectype, String apiName) {
            this.label = label;
            this.value = value;
            this.sobjectype = sobjectype;
            this.apiName = apiName;
        }

        public Integer compareTo(Object compareTo) {
            MergeField mf = (MergeField)compareTo;
            return this.apiName.compareTo(mf.apiName);
        }
    }

    public static Object getAppPermissions(Object data) {
        Map<String, Object> result = new Map<String, Object> {
            'JiraIntegrationEnabled' => PermissionsUtil.JiraIntegrationEnabled,
            'SlackIntegrationEnabled' => PermissionsUtil.SlackIntegrationEnabled,
            'PagerDutyIntegrationEnabled' => PermissionsUtil.PagerDutyIntegrationEnabled,
            'SplunkIntegrationEnabled' => PermissionsUtil.SplunkIntegrationEnabled,
            'MonitoringEnabled' => PermissionsUtil.MonitoringEnabled,
            'MaxMonitoringRules' => PermissionsUtil.MaxMonitoringRules,
            'ArchivalEnabled' => PermissionsUtil.ArchivalEnabled,
            'MaxArchivalRules' => PermissionsUtil.MaxArchivalRules,
            'MaxConnectedOrgs' => PermissionsUtil.MaxConnectedOrgs,
            'MaxJiraRules' => PermissionsUtil.MaxJiraRules,
            'SensitiveDataMaskingEnabled' => PermissionsUtil.SensitiveDataMaskingEnabled,
            'NotificationIntegrationEnabled' => PermissionsUtil.NotificationIntegrationEnabled,
            'MaxNotificationRules' => PermissionsUtil.MaxNotificationRules,
            'FlowDebugViewEnabled' => PermissionsUtil.FlowDebugViewEnabled,
            'BulkAPITrackingEnabled' => PermissionsUtil.BulkAPITrackingEnabled,
            'IntegrationDebugViewEnabled' => PermissionsUtil.IntegrationDebugViewEnabled,
            'TeamsIntegrationEnabled' => PermissionsUtil.TeamsIntegrationEnabled,
            'GitHubIntegrationEnabled' => PermissionsUtil.GitHubIntegrationEnabled,
            'ChangeTrackingEnabled' => PermissionsUtil.ChangeTrackingEnabled
        };
        return result;
    }

    public static List<RemoteSiteSettingsWrapper> getRemoteSiteSettings() {
        return getRemoteSiteSettings(UserInfo.getSessionId());
    }

    public static List<RemoteSiteSettingsWrapper> getRemoteSiteSettings(String sessionId) {
        List<RemoteSiteSettingsWrapper> remoteSiteSettingsList = new List<RemoteSiteSettingsWrapper>();
        try {
            String b = HttpUtils.get(
                ConfigUtil.TOOLING_QUERY_ENDPOINT + ConfigUtil.REST_REMOTE_SITE_SETTINGS_QUERY,
                ConfigUtil.getRemoteSiteSettingsHeadersMap(sessionId),
                200
            );
            Map<String, Object> respResults = (Map<String, Object>)JSON.deserializeUntyped(b);
            if (respResults.get(ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS) != null) {
                remoteSiteSettingsList = (List<RemoteSiteSettingsWrapper>)JSON.deserialize(JSON.serialize(respResults.get(ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS)), List<RemoteSiteSettingsWrapper>.class);
                return remoteSiteSettingsList;
            }
        }
        catch(Exception e){}
        return remoteSiteSettingsList;
    }

    public static Object getConnectedOrgsInfo() {
        Map<String, Object> output = new Map<String, Object>();
        output.put(ConfigUtil.CONNECTED_ORGS_INFO_KEY_SETTINGS, new ConnectedOrgsSettings(ConfigUtil.CONNECTED_ORGS_SETTINGS));
        List<ConnectedOrgDTO> corgs = new List<ConnectedOrgDTO>();
        for (Connected_Org__c corg : ConnectedOrgService.getConnectedOrgsList()) {
            corgs.add(new ConnectedOrgDTO(corg));
        }
        output.put(ConfigUtil.CONNECTED_ORGS_INFO_KEY_CONNECTED_ORGS, corgs);
        return output;
    }


    public static Object getSelfConnectedOrgsInfo() {
        Map<String, Object> output = new Map<String, Object>();
        output.put(ConfigUtil.CONNECTED_ORGS_INFO_KEY_SETTINGS, new ConnectedOrgsSettings(ConfigUtil.CONNECTED_ORGS_SETTINGS));
        output.put(ConfigUtil.CURRENT_ORG_IS_SANDBOX_KEY, ConfigUtil.currentOrgIsSandbox());
        List<ConnectedOrgDTO> corgs = new List<ConnectedOrgDTO>();
        Connected_Org__c selfCorg = ConnectedOrgService.getConnectedOrgById(UserInfo.getOrganizationId());
        if(selfCorg != null) {
            corgs.add(new ConnectedOrgDTO(selfCorg));
        }
        output.put(ConfigUtil.CONNECTED_ORGS_INFO_KEY_CONNECTED_ORGS, corgs);
        return output;
    }

    public static Object updatePassthroughtMode(Object payload) {
        ConnectedOrgsSettings s = (ConnectedOrgsSettings)JSON.deserialize(JSON.serialize(payload), ConnectedOrgsSettings.class);
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c = s.passthroughtMode;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Email__c = s.passthroughConnection;
        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;
        ConfigUtil.initConnectedOrgsSettings();
        return new ConnectedOrgsSettings(ConfigUtil.CONNECTED_ORGS_SETTINGS);
    }

    public static Object createConnectionOrg(Object payload) {
        ConnectedOrgCreateData d = (ConnectedOrgCreateData)JSON.deserialize(JSON.serialize(payload), ConnectedOrgCreateData.class);
        Connected_Org__c corg = ConnectedOrgService.createConnectedOrg(d.name, d.type, d.description, d.source, d.dataDirection);
        Map<String, Object> output = new Map<String, Object>();
        output.put(ConfigUtil.CONNECTION_ORG_KEY_CORG, new ConnectedOrgDTO(corg));
        output.put(ConfigUtil.CONNECTION_ORG_KEY_CLIENT_KEY, ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c);
        output.put('useManagedApp', ConfigUtil.CONNECTED_ORGS_SETTINGS.Use_Managed_App__c);
        return output;
    }

    public static Object createSelfConnectionOrg(Object payload) {
        ConnectedOrgCreateData d = (ConnectedOrgCreateData)JSON.deserialize(JSON.serialize(payload), ConnectedOrgCreateData.class);
        Connected_Org__c corg = ConnectedOrgService.createSelfConnectedOrg(d.name, d.description);
        Map<String, Object> output = new Map<String, Object>();
        output.put(ConfigUtil.CONNECTION_ORG_KEY_CORG, new ConnectedOrgDTO(corg));
        return output;
    }

    public static Object updateConnectedOrg(Object payload) {
        ConnectedOrgDTO d = (ConnectedOrgDTO)JSON.deserialize(JSON.serialize(payload), ConnectedOrgDTO.class);
        Connected_Org__c corg = ConnectedOrgService.getConnectedOrgById(d.orgId);
        if (corg == null) {
            throw new AdminServiceException(ConfigUtil.EXCEPTION_CONNECTED_ORG_NOT_FOUND);
        }
        corg.Title__c = d.name;
        corg.Description__c = d.description;
        corg.Data_Direction__c = d.dataDirection;
        update corg;

        Map<String, Object> output = new Map<String, Object>();
        output.put(ConfigUtil.CONNECTION_ORG_KEY_CORG, new ConnectedOrgDTO(corg));
        output.put(ConfigUtil.CONNECTION_ORG_KEY_CLIENT_KEY, ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c);
        output.put('useManagedApp', ConfigUtil.CONNECTED_ORGS_SETTINGS.Use_Managed_App__c);
        return output;
    }

    public static Object refreshConnectedOrgToken(Object payload) {
        ConnectedOrgDTO d = (ConnectedOrgDTO)JSON.deserialize(JSON.serialize(payload), ConnectedOrgDTO.class);
        Connected_Org__c corg = ConnectedOrgService.refreshToken(d.orgId);
        update corg;
        return new ConnectedOrgDTO(corg);
    }

    public static Object testConnectedOrg(Object payload) {
        ConnectedOrgDTO d = (ConnectedOrgDTO)JSON.deserialize(JSON.serialize(payload), ConnectedOrgDTO.class);
        if (ConnectedOrgService.testConnection(d.orgId)) {
            return ConfigUtil.CONNECTED_ORG_TESTING_KEY_SUCCESS;
        } else {
            return ConfigUtil.CONNECTED_ORG_TESTING_KEY_FAIL;
        }
    }

    public static Object deleteFakeConnectedOrg() {
        ConnectedOrgService.deleteFakeConnectedOrgs();
        return true;
    }

    public static Object deleteConnectedOrg(Object payload) {
        ConnectedOrgDTO d = (ConnectedOrgDTO)JSON.deserialize(JSON.serialize(payload), ConnectedOrgDTO.class);
        Connected_Org__c corg = Connected_Org__c.getInstance(d.orgId);  //get connect org by exact org id to ensure invalid org ids can be deleted
        if (corg == null) {
            throw new AdminServiceException(ConfigUtil.EXCEPTION_CONNECTED_ORG_DELETE_FAIL);
        }
        deleteRemoteSiteSettingsMetadata(corg.Name);
        delete corg;
        return true;
    }

    public class ConnectedOrgsSettings {
        public Boolean passthroughtMode = false;
        public String passthroughConnection;
        public String clientKey;
        public String clientSecret;
        public Boolean connectedAppCreatedLessThan10Mins;
        public Datetime connectedAppCreatedAt;
        public String connectedAppId;
        public String connectedAppName;
        public Boolean schedulerEnabled = false;
        public ConnectedOrgsSettings() {}
        public ConnectedOrgsSettings(Connected_Orgs_Settings__c connectedOrgsSettings) {
            this.passthroughConnection = connectedOrgsSettings.Passthrought_Email__c;
            this.passthroughtMode = connectedOrgsSettings.Passthrought_Mode__c;
            this.clientKey = connectedOrgsSettings.Client_Key__c;
            this.clientSecret = connectedOrgsSettings.Client_Secret__c;
            this.schedulerEnabled = connectedOrgsSettings.Service_Scheduler_Enabled__c;
            this.connectedAppCreatedAt = connectedOrgsSettings.Connected_App_Created_At__c;
            this.connectedAppCreatedLessThan10Mins = connectedOrgsSettings.Connected_App_Created_At__c != null && connectedOrgsSettings.Connected_App_Created_At__c > Datetime.now().addMinutes(-10);
            this.connectedAppId = connectedOrgsSettings.Connected_App_ID__c;
            this.connectedAppName = connectedOrgsSettings.Connected_App_Name__c;
        }
    }

    public class ConnectedOrgDTO {
        public String recordId;
        public String orgId;
        public String name;
        public String description;
        public String type;
        public String instanceUrl;
        public String accessToken;
        public String refreshToken;
        public Datetime tokenRefreshedAt;
        public Boolean schedulerEnabled;
        public String source;
        public String dataDirection;
        public ConnectedOrgDTO(Connected_Org__c corg) {
            recordId = corg.Id;
            orgId = corg.Name;
            name = corg.Title__c;
            type = corg.Type__c;
            instanceUrl = corg.Instance_Url__c;
            description = corg.Description__c;
            accessToken = corg.Access_Token__c;
            refreshToken = corg.Refresh_Token__c;
            tokenRefreshedAt = corg.Token_Refreshed_At__c;
            schedulerEnabled = corg.Scheduler_Enabled__c;
            source = corg.Source__c;
            dataDirection = corg.Data_Direction__c;
        }
    }

    public class ConnectedOrgCreateData {
        public String name;
        public String type;
        public String description;
        public String source;
        public String dataDirection;
    }

    public static String BASE_REMOTE_SITE_SETTINGS_NAME = 'Pharos_ai_Base_URL';
    public static String CONNECTED_ORG_REMOTE_SITE_SETTINGS_NAME = 'Pharos_ai_Connected_Org_';

    public static List<DefaultRemoteSiteSetting> defaultRemoteSiteSettings = new List<DefaultRemoteSiteSetting> {
        new DefaultRemoteSiteSetting(
            'https://login.salesforce.com',
            'Pharos_ai_Sfdc_Prod_Login_URL',
            'Login URL for salesforce production orgs'),
        new DefaultRemoteSiteSetting(
            'https://test.salesforce.com',
            'Pharos_ai_Sfdc_Sandbox_Login_URL',
            'Login URL for salesforce sandbox orgs'),
        new DefaultRemoteSiteSetting(
            System.URL.getOrgDomainUrl().toExternalForm(),
            'Pharos_ai_Base_URL',
            'Pharos.ai callback URL in this org')
    };

    public class DefaultRemoteSiteSetting {
        public String url;
        public String name;
        public String description;

        public DefaultRemoteSiteSetting(String url, String name, String description) {
            this.url = url;
            this.name = name;
            this.description = description;
        }
    }

    public static Object setupRemoteSiteSettings() {
        for(DefaultRemoteSiteSetting drss : defaultRemoteSiteSettings) {
            upsertRemoteSiteSetting(drss.name, drss.url, drss.description);
        }
        return 'success';
    }

    public static Map<String, RemoteSiteSettingsWrapper> getRemoteSiteSettingsMap() {
        Map<String, RemoteSiteSettingsWrapper> output = new Map<String, RemoteSiteSettingsWrapper>();
        for (RemoteSiteSettingsWrapper rss : getRemoteSiteSettings()) {
            output.put(rss.EndpointUrl, rss);
        }
        return output;
    }

    public static MetadataService.MetadataPort createMetadataPort() {
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;
    }

    public static void upsertRemoteSiteSettingsMetadata(MetadataService.RemoteSiteSetting rss) {
        MetadataService.MetadataPort service = createMetadataPort();

        List<MetadataService.UpsertResult> results =
            service.upsertMetadata(
                new MetadataService.Metadata[] {rss});
        handleUpsertResults(results[0]);
    }

    public static void upsertRemoteSiteSetting(String name, String url, String description) {
        Map<String, RemoteSiteSettingsWrapper> createdRemoteSiteSettings = getRemoteSiteSettingsMap();
        if (createdRemoteSiteSettings.containsKey(url) && createdRemoteSiteSettings.get(url).SiteName == name) {
            return;
        }

        MetadataService.RemoteSiteSetting rss = createRemoteSiteSettingInstance(name, url, description);
        upsertRemoteSiteSettingsMetadata(rss);
    }

    public static MetadataService.RemoteSiteSetting createRemoteSiteSettingInstance(String name, String url, String description) {
        MetadataService.RemoteSiteSetting rss = new MetadataService.RemoteSiteSetting();
        rss.fullName = name;
        rss.description = description;
        rss.disableProtocolSecurity = false;
        rss.isActive = true;
        rss.url = url;
        return rss;
    }

    public static Boolean checkRemoteSiteSettings() {
        Boolean result = true;
        try {
            Map<String, RemoteSiteSettingsWrapper> createdRemoteSiteSettings = getRemoteSiteSettingsMap();
            for(DefaultRemoteSiteSetting drss : defaultRemoteSiteSettings) {
                result = (result && createdRemoteSiteSettings.containsKey(drss.url) && createdRemoteSiteSettings.get(drss.url).SiteName == drss.name);
            }
        }
        catch(Exception e) {
            result = false;
        }
        return result;
    }

    public static Logger_Settings__c getCustomSettings() {
        return Logger_Settings__c.getOrgDefaults();
    }

    public static Logger_Settings__c saveCustomSettings(Object data) {
        Logger_Settings__c settings = (Logger_Settings__c)JSON.deserialize(JSON.serialize(data), Logger_Settings__c.class);
        upsert settings;
        return getCustomSettings();
    }

    public static SlackSettings getSlackSettings() {
        String defaultTemplate = (String.isNotBlank(ConfigUtil.SLACK_SETTINGS.Slack_Message_Template__c))
            ? ConfigUtil.SLACK_SETTINGS.Slack_Message_Template__c
            : ConfigUtil.SLACK_DEFAULT_MESSAGE_TEMPLATE;

        SlackSettings settings = new SlackSettings(ConfigUtil.SLACK_SETTINGS, defaultTemplate);

        OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance('Slack');
        if(mdtSettings != null) {
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_SCOPE, mdtSettings.Scope__c);

            Map<String, Object> state = new Map<String, Object>{
                    'redirectUrl' => System.Url.getSalesforceBaseUrl().toExternalForm() + '/apex/' + ConfigUtil.getNameSpacePrefix() + 'Settings',
                    'isSlack' => true
            };

            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_STATE, EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state))));
            settings.oAuthEndpoint = ConfigUtil.SLACK_AUTHORIZE_URL + bodyParams.toStringParameters('?');
        }
        return settings;
    }

    public static List<Object> getSlackChannels() {
        return SlackService.getChannels();
    }

    public static String saveSlackSettings(Object payload) {
        SlackSettings slackSettings = (SlackSettings)JSON.deserialize(JSON.serialize(payload), SlackSettings.class);
        ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c = slackSettings.slackEnabled;
        if (String.isNotBlank(slackSettings.slackToken) && slackSettings.slackToken != ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c) {
            ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c = slackSettings.slackToken;
        }
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_API_URL, ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_DESCRIPTION);
        upsert ConfigUtil.SLACK_SETTINGS;

        return ConfigUtil.SAVE_SLACK_SETTINGS_SUCCESS;
    }

    public static PagerDutySettings getPagerDutySettings() {
        return new PagerDutySettings(ConfigUtil.PAGER_DUTY_SETTINGS);
    }

    public static List<Object> getPagerDutyServices() {
        return PagerDutyService.getServices();
    }

    public static String savePagerDutySettings(Object payload) {

        PagerDutySettings pdSettings = (PagerDutySettings)JSON.deserialize(JSON.serialize(payload), PagerDutySettings.class);

        if (String.isNotBlank(pdSettings.token) && pdSettings.token != ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_API_Token__c) {
            ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_API_Token__c = pdSettings.token;
        }
        ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_Enabled__c = pdSettings.enabled;
        ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_Service_ID__c = pdSettings.serviceId;
        ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_Service_Integration_Key__c = pdSettings.serviceIntegrationKey;
        ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_User_Email__c = pdSettings.userEmail;
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_URL, ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_DESCRIPTION);
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_URL, ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_DESCRIPTION);
        upsert ConfigUtil.PAGER_DUTY_SETTINGS;
        return ConfigUtil.SAVE_PAGER_DUTY_SETTINGS_SUCCESS;
    }

    public static Map<String, String> checkEmailAccess() {
        Map<String, String> data = new Map<String, String>();
        PageReference emailSettingsPage = new PageReference('/email-admin/editOrgEmailSettings.apexp');
        String htmlBody = emailSettingsPage.getContent().toString().replace('\n','');
        String accessLevel = htmlBody.substringBetween(' selected="selected">','</option>');
        data.put('access', accessLevel);
        return data;
    }

    public static Map<String, Object> getEmailServiceData() {
        return getEmailServiceData(getAutomatedFlowErrorTracking(), getEmailToCaseErrorTracking(), getEmailToCaseErrorTrackingType(), getEmailToCaseErrorTrackingAvailable());
    }

    public static List<EmailServicesFunction> getPackageEmailServicesFunctions() {
        Id ehId = getEmailHandlerApexClassId();
        List<EmailServicesFunction> availableEmailServices = [
            SELECT Id, IsActive, FunctionName, ErrorRoutingAddress, AuthorizedSenders, ApexClassId
            FROM EmailServicesFunction
            WHERE ApexClassId = :ehId AND FunctionName = :ConfigUtil.EMAIL_SERVICE_HANDLER_NAME
            LIMIT 1
        ];
        return availableEmailServices;
    }

    public static String getPackageEmailServiceFunctionEmailAddress() {
        List<EmailServicesFunction> packageFunctions = getPackageEmailServicesFunctions();
        if(!packageFunctions.isEmpty()) {
            List<EmailServicesAddress> adresses = [
                SELECT LocalPart, EmailDomainName, IsActive
                FROM EmailServicesAddress
                WHERE FunctionId = :packageFunctions.get(0).Id
                LIMIT 1
            ];
            if(!adresses.isEmpty()) {
                return getEmailFromEmailServiceAddress(adresses.get(0));
            }
        }
        return null;
    }

    public static String getEmailFromEmailServiceAddress(EmailServicesAddress address) {
        return address.LocalPart.toLowerCase() + ConfigUtil.EMAIL_SERVICE_DATA_KEY_EMAIL_SYMBOL + address.EmailDomainName;
    }


    public static Map<String, Object> getEmailServiceData(Boolean flowErrorTracking, Boolean emailToCaseErrorTracking, String emailToCaseErrorTrackingType, Boolean emailToCaseErrorTrackingAvailable) {
        Map<String, Object> output = new Map<String, Object>{
            ConfigUtil.EMAIL_SERVICE_DATA_KEY_EMAIL => null,
            ConfigUtil.EMAIL_SERVICE_DATA_KEY_ERROR_CODE => 0,
            ConfigUtil.EMAIL_SERVICE_DATA_KEY_CONFIRMED => false,
            ConfigUtil.CONFIRM_AUTOMATED_FLOW_ERROR_TRACKING_KEY => false
        };
        output.put(ConfigUtil.EMAIL_SERVICE_DATA_KEY_CONFIRMED, ConfigUtil.SETTINGS.Email_Service_Confirmed__c);
        output.put(ConfigUtil.CONFIRM_AUTOMATED_FLOW_ERROR_TRACKING_KEY, flowErrorTracking);
        output.put(ConfigUtil.CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_KEY, ConfigUtil.SETTINGS.Enable_Email_To_Case_Error_Tracking__c);
        output.put(ConfigUtil.CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_KEY, ConfigUtil.SETTINGS.Enable_Email_To_Case_Error_Tracking__c == ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED);
        output.put(ConfigUtil.CONFIRM_EMAIL_TO_CASE_ERROR_TRACKING_ENABLED_KEY, emailToCaseErrorTracking);
        output.put('emailToCaseErrorTrackingAvailable', emailToCaseErrorTrackingAvailable);
        output.put('emailToCaseErrorTrackingType', emailToCaseErrorTrackingType);
        List<EmailServicesFunction> availableEmailServices = getPackageEmailServicesFunctions();
        if (availableEmailServices.size() == 0) {
            // throw new AdminServiceException('Email Service not found');
            output.put(ConfigUtil.EMAIL_SERVICE_DATA_KEY_ERROR_CODE, 1001);
            return output;
        } else if (availableEmailServices.size() > 1) {
            throw new AdminServiceException(ConfigUtil.MANY_EMAIL_SERVICE_FOUND_MESSAGE);
        }
        output.put('emailServicesFunctionIsActive', availableEmailServices.get(0).IsActive);
        List<EmailServicesAddress> adresses = [
            SELECT LocalPart, EmailDomainName, IsActive
            FROM EmailServicesAddress
            WHERE FunctionId = :availableEmailServices
        ];
        if (adresses.size() == 0) {
            output.put(ConfigUtil.EMAIL_SERVICE_DATA_KEY_ERROR_CODE, 1002);
            return output;
        }
        output.put(ConfigUtil.EMAIL_SERVICE_DATA_KEY_EMAIL, getEmailFromEmailServiceAddress(adresses.get(0)));
        output.put('emailServicesFunctionIsActive', availableEmailServices.get(0).IsActive);
        return output;
    }

    public static Map<String, Object> getLoggerWrapperInfo() {
        Map<String, String> output = new Map<String, String>{};
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :ConfigUtil.APEX_UTIL_RESOURCE_NAME LIMIT 1];
        StaticResource srTest = [SELECT Body FROM StaticResource WHERE Name = :ConfigUtil.APEX_UTIL_TEST_RESOURCE_NAME LIMIT 1];
        if (sr == null) {
            throw new AdminServiceException(ConfigUtil.APEXUTILSOURCE_NOT_FOUND_MESSAGE);
        }
        if (srTest == null) {
            throw new AdminServiceException(ConfigUtil.APEXUTILTESTSOURCE_NOT_FOUND_MESSAGE);
        }
        String loggerWrapperCode = sr.Body.toString();
        String loggerWrapperTestCode = srTest.Body.toString();
        String loggerWrapperCodeWithNS = loggerWrapperCode.replaceAll('pharos', ConfigUtil.NS);
        String loggerWrapperTestCodeWithNS = loggerWrapperTestCode.replaceAll('pharos', ConfigUtil.NS);
        output.put(ConfigUtil.LOGGER_WRAPPER_INFO_KEY_CODE, loggerWrapperCodeWithNS);
        output.put(ConfigUtil.LOGGER_WRAPPER_INFO_KEY_TEST_CODE, loggerWrapperTestCodeWithNS);
        return output;
    }

    public class EmailServicesFunctionWrapper {
        public Boolean IsActive;
    }

    public static void updateEmailServicesFunction(String emailServicesFunctionId, Boolean isActive) {
        EmailServicesFunctionWrapper data = new EmailServicesFunctionWrapper();
        data.IsActive = isActive;
        String b = HttpUtils.post(
            ConfigUtil.TOOLING_API_UPDATE_APEX_EMAIL_SERVICE_FUNCTION + emailServicesFunctionId + ConfigUtil.OVERRIDE_HTTP_METHOD_PATCH,
            JSON.serialize(data),
            getToolingHeaders(),
            204
        );
    }

    public static Map<String, Object> createEmailService(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        Boolean incomingValue = Boolean.valueOf(input.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_VALUE));
        Id ehClassId = getEmailHandlerApexClassId();
        List<EmailServicesFunction> availableEmailServices = [
            SELECT Id, IsActive, FunctionName, ApexClassId
            FROM EmailServicesFunction
            WHERE ApexClassId = :ehClassId AND FunctionName = :ConfigUtil.EMAIL_SERVICE_HANDLER_NAME
        ];
        if(!incomingValue && !availableEmailServices.isEmpty()) {
            updateEmailServicesFunction(availableEmailServices.get(0).Id, incomingValue);
        }
        else if(incomingValue) {
            Id functionId;
            SObjectsCreateResponse response;
            String b;

            if(!availableEmailServices.isEmpty()) {
                updateEmailServicesFunction(availableEmailServices.get(0).Id, incomingValue);
                functionId = availableEmailServices.get(0).Id;
            }
            if(availableEmailServices.isEmpty()) {
                b = HttpUtils.post(
                    ConfigUtil.EMAIL_SERVICES_FUNCTION_ENDPOINT,
                    ConfigUtil.getRequestBodyCreateEmailServiceFunction(ehClassId),
                    ConfigUtil.SF_REST_API_HEADERS,
                    201
                );

                try {
                    response = (SObjectsCreateResponse)JSON.deserialize(b, SObjectsCreateResponse.class);
                    functionId = response.id;
                }
                catch(Exception e) {
                    throw new AdminServiceException(b);
                }
            }

            b = HttpUtils.post(
                ConfigUtil.EMAIL_SERVICES_ADDRESS_ENDPOINT,
                ConfigUtil.getRequestBodyCreateEmailService(functionId),
                ConfigUtil.SF_REST_API_HEADERS,
                201
            );
            try {
                response = (SObjectsCreateResponse)JSON.deserialize(b, SObjectsCreateResponse.class);
            }
            catch(Exception e) {
                throw new AdminServiceException(b);
            }
            try {
                ApexEmailNotificationWrapper apexEmailNotification = getApexEmailNotification();
                String errorEmailServiceAddress = getPackageEmailServiceFunctionEmailAddress();
                upsertApexEmailNotification(errorEmailServiceAddress, apexEmailNotification);
            }
            catch(Exception e) {
                throw new AdminServiceException(e);
            }
        }
        return getEmailServiceData();
    }

    public static void upsertApexEmailNotification(String errorEmailServiceAddress, ApexEmailNotificationWrapper apexEmailNotification) {
        Map<String, Object> ApexEmailNotificationData = new Map<String, Object>{
            'Email' => errorEmailServiceAddress
        };
        if(apexEmailNotification == null) {
            ApexEmailNotificationData.put('UserId', '');
            String b = HttpUtils.post(
                ConfigUtil.TOOLING_API_CREATE_APEX_EMAIL_NOTIFICATION,
                JSON.serialize(ApexEmailNotificationData),
                getToolingHeaders(),
                201
            );
        }
        else {
            String b = HttpUtils.post(
                ConfigUtil.TOOLING_API_UPDATE_APEX_EMAIL_NOTIFICATION + apexEmailNotification.Id + ConfigUtil.OVERRIDE_HTTP_METHOD_PATCH,
                JSON.serialize(ApexEmailNotificationData),
                getToolingHeaders(),
                204
            );
        }

    }

    public static ApexEmailNotificationWrapper getApexEmailNotification() {
        ApexEmailNotificationWrapper result;
        String b = HttpUtils.get(
            ConfigUtil.TOOLING_QUERY_ENDPOINT + ConfigUtil.TOOLING_QUERY_GET_EMAIL_APEX_EMAIL_NOTIFICATION,
            getToolingHeaders(),
            200
        );
        Map<String, Object> respResults = (Map<String, Object>)JSON.deserializeUntyped(b);
        if (respResults.get(ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS) != null) {
            List<ApexEmailNotificationWrapper> apexEmailNotificationWrappers =
                    (List<ApexEmailNotificationWrapper>)JSON.deserialize(JSON.serialize(respResults.get(ConfigUtil.REMOTE_SITE_SETTINGS_KEY_RECORDS)), List<ApexEmailNotificationWrapper>.class);
            if(!apexEmailNotificationWrappers.isEmpty()) {
                result = apexEmailNotificationWrappers.get(0);
            }
        }
        return result;
    }

    public class ApexEmailNotificationWrapper {
        public String Id;
        public String Email;
    }

    public static Map<String, String> getToolingHeaders() {
        return new Map<String, String> {
            'Authorization' => 'Bearer ' + UserInfo.getSessionId(),
            'Content-Type' => 'application/json'
        };
    }

    public static Map<String, Object> confirmEmailService(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        boolean flowErrorTracking = getAutomatedFlowErrorTracking();
        boolean emailToCaseErrorTracking = getEmailToCaseErrorTracking();
        boolean emailToCaseErrorTrackingAvailable = getEmailToCaseErrorTrackingAvailable();
        String emailToCaseErrorTrackingType = getEmailToCaseErrorTrackingType();
        Map<String, Object> emailResult = getEmailServiceData(flowErrorTracking, emailToCaseErrorTracking, emailToCaseErrorTrackingType, emailToCaseErrorTrackingAvailable);
        ConfigUtil.SETTINGS.Email_Service_Confirmed__c = Boolean.valueOf(input.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_VALUE));
        // Custom SETTINGS -> Email_Service_Address__c
        if (String.isNotBlank((String)emailResult.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_EMAIL))) {
            ConfigUtil.SETTINGS.Email_Service_Address__c = (String)emailResult.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_EMAIL);
        }
        upsert ConfigUtil.SETTINGS;
        return getEmailServiceData(flowErrorTracking, emailToCaseErrorTracking, emailToCaseErrorTrackingType, emailToCaseErrorTrackingAvailable);
    }

    @future(Callout=true)
    public static void checkEmailToCaseErrorTrackingSettings() {
        if(ConfigUtil.SETTINGS.Enable_Email_To_Case_Error_Tracking__c == ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED) {
            boolean emailToCaseErrorTracking = getEmailToCaseErrorTracking();
            if(!emailToCaseErrorTracking) {
                setEmailToCaseTracking(true);
            }
        }
    }

    public static Boolean getEmailToCaseErrorTrackingAvailable() {
        Boolean result = false;

        String errorHandlerAddress = getPackageEmailServiceFunctionEmailAddress();
        if(String.isNotBlank(errorHandlerAddress)) {
            try {
                MetadataService.CaseSettings caseSettings = getCaseSettings();
                if(caseSettings != null && caseSettings.emailToCase != null && caseSettings.emailToCase.enableEmailToCase) {
                    result = true;
                }
            }
            catch(Exception e){}
        }
        return result;
    }

    public static String getEmailToCaseErrorTrackingType() {
        String result = null;

        String errorHandlerAddress = getPackageEmailServiceFunctionEmailAddress();
        if(String.isNotBlank(errorHandlerAddress)) {
            try {
                MetadataService.CaseSettings caseSettings = getCaseSettings();
                if(caseSettings != null && caseSettings.emailToCase != null && caseSettings.emailToCase.enableEmailToCase) {
                    // User
                    if(String.isNotBlank(caseSettings.defaultCaseUser)) {
                        result = 'User';
                    }
                    //System
                    else if (String.isNotBlank(caseSettings.systemUserEmail)) {
                        result = 'System';
                    }
                }
            }
            catch(Exception e){}
        }
        return result;
    }

    public static Boolean getEmailToCaseErrorTracking() {
        Boolean result = false;

        String errorHandlerAddress = getPackageEmailServiceFunctionEmailAddress();
        if(String.isNotBlank(errorHandlerAddress)) {
            MetadataService.CaseSettings caseSettings = getCaseSettings();
            if(caseSettings != null && caseSettings.emailToCase != null && caseSettings.emailToCase.enableEmailToCase) {
                // User
                if(String.isNotBlank(caseSettings.defaultCaseUser)) {
                    List<User> users = [SELECT Email FROM User WHERE UserName =:caseSettings.defaultCaseUser LIMIT 1];
                    result = (!users.isEmpty() && users.get(0).Email == errorHandlerAddress);
                }
                //System
                else if (String.isNotBlank(caseSettings.systemUserEmail)) {
                    result = caseSettings.systemUserEmail == errorHandlerAddress;
                }
            }
        }
        return result;
    }

    public static Boolean getAutomatedFlowErrorTracking() {
        Boolean result = false;
        try {
            MetadataService.FlowSettings flowSettings = getFlowSettings();
            result = flowSettings.enableFlowUseApexExceptionEmail;
        }
        catch(Exception e){}
        return result;
    }

    public static MetadataService.FlowSettings getFlowSettings() {
        MetadataService.MetadataPort service = createMetadataPort();
        service.setMetadataAPIVersion('48.0');

        MetadataService.FlowSettings flowSettings =
            (MetadataService.FlowSettings) service.readMetadata('FlowSettings',
                new String[] { 'Flow' }).getRecords()[0];

        return flowSettings;
    }

    public static MetadataService.MetadataPort getCaseSettingsService() {
        MetadataService.MetadataPort service = createMetadataPort();
        service.setMetadataAPIVersion('50.0');
        return service;
    }

    public static MetadataService.CaseSettings getCaseSettings() {
        MetadataService.MetadataPort service = getCaseSettingsService();

        List<MetadataService.CaseSettings> caseSettingsList =
            (List<MetadataService.CaseSettings>) service.readMetadata('CaseSettings',
                new String[] { 'Case' }).getRecords();
        MetadataService.CaseSettings caseSettings = (!caseSettingsList.isEmpty()) ? caseSettingsList.get(0): null;
        return caseSettings;
    }

    public static void setAutomatedFlowErrorTracking(Boolean value) {
        MetadataService.MetadataPort service = createMetadataPort();
        service.setMetadataAPIVersion('48.0');

        MetadataService.FlowSettings flowSettings = getFlowSettings();
        flowSettings.enableFlowUseApexExceptionEmail = value;

        List<MetadataService.SaveResult> results =
            service.updateMetadata(
                new MetadataService.Metadata[] {flowSettings});
        handleSaveResults(results[0]);
    }

    public static Boolean setEmailToCaseTracking(Boolean value) {
        String errorHandlerAddress = getPackageEmailServiceFunctionEmailAddress();
        if(value && String.isNotBlank(errorHandlerAddress)) {
            MetadataService.CaseSettings caseSettings = getCaseSettings();
            if(caseSettings != null && caseSettings.emailToCase != null && caseSettings.emailToCase.enableEmailToCase) {
                // User
                if(String.isNotBlank(caseSettings.defaultCaseUser)) {
                    List<User> caseErrorUser = [SELECT Id, Email FROM User WHERE Username = :caseSettings.defaultCaseUser LIMIT 1];
                    if(!caseErrorUser.isEmpty() && caseErrorUser.get(0).Email == errorHandlerAddress) {
                        setEmailToCaseErrorTrackingStatus(ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED);
                    }
                    else if(!caseErrorUser.isEmpty()) {
                        PermissionsUtil.putSObjectField(caseErrorUser.get(0), Schema.sObjectType.User.fields.Email, errorHandlerAddress);
                        PermissionsUtil.performUpdateDML(caseErrorUser, Schema.sObjectType.User);

                        PermissionsUtil.putSObjectField(ConfigUtil.SETTINGS, Schema.sObjectType.Logger_Settings__c.fields.Enable_Email_To_Case_Error_Tracking__c, ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_PENDING);
                        PermissionsUtil.performUpdateDML(new List<Logger_Settings__c>{ConfigUtil.SETTINGS}, Schema.sObjectType.Logger_Settings__c);
                    }
                    return true;
                }
                //System
                else if (String.isNotBlank(caseSettings.systemUserEmail)) {
                    caseSettings.systemUserEmail = errorHandlerAddress;
                    List<MetadataService.SaveResult> results =
                        getCaseSettingsService().updateMetadata(
                            new MetadataService.Metadata[] {caseSettings});
                    handleSaveResults(results[0]);

                    setEmailToCaseErrorTrackingStatus(ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED);
                    return true;
                }
            }
            else {
                setEmailToCaseErrorTrackingStatus(ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ERROR);
            }
        }
        else {
            PermissionsUtil.putSObjectField(ConfigUtil.SETTINGS, Schema.sObjectType.Logger_Settings__c.fields.Enable_Email_To_Case_Error_Tracking__c, ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_DISABLED);
            PermissionsUtil.performUpdateDML(new List<Logger_Settings__c>{ConfigUtil.SETTINGS}, Schema.sObjectType.Logger_Settings__c);
        }
        return false;
    }


    public static void handleChangeUserEmail(String subject, String body) {
        String changeEmailLink = getTokenValue(body, PATTERN_CHANGE_EMAIL_LINK, 0);
        String emailHandlerAddress = getPackageEmailServiceFunctionEmailAddress();

        if(String.isNotBlank(emailHandlerAddress)
            && String.isNotBlank(changeEmailLink)
            && body.containsIgnoreCase(emailHandlerAddress)) {

            try {
                HttpUtils.get(changeEmailLink, null, 200);
                setEmailToCaseErrorTrackingStatus(ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED);
            }
            catch(Exception e) {
                setEmailToCaseErrorTrackingStatus(ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ERROR);
            }

        }
    }

    @future(callout = true)
    public static void setEmailToCaseErrorTrackingStatus(String status){
        PermissionsUtil.putSObjectField(ConfigUtil.SETTINGS, Schema.sObjectType.Logger_Settings__c.fields.Enable_Email_To_Case_Error_Tracking__c, status);
        PermissionsUtil.performUpdateDML(new List<Logger_Settings__c>{ConfigUtil.SETTINGS}, Schema.sObjectType.Logger_Settings__c);
    }

    public static final Pattern PATTERN_CHANGE_EMAIL_LINK = Pattern.compile('(http|https)://([\\w_-]+(?:(?:\\.[\\w_-]+)+))([\\w.,@?^=%&:/~+#-]*[\\w@?^=%&/~+#-])?');

    public static String getTokenValue(String value, Pattern pattern, Integer groupIndex) {
        String result;
        Pattern p = pattern;
        Matcher pm = p.matcher(value);

        if (pm.find()) {
            result = pm.group(groupIndex);
        }

        return result;
    }

    public static final String ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_PENDING = 'Pending';
    public static final String ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED = 'Enabled';
    public static final String ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ERROR = 'Error';
    public static final String ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_DISABLED = null;

    public static Map<String, Object> emailToCaseTracking(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        Boolean incomingValue = Boolean.valueOf(input.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_VALUE));

        Boolean flowErrorTracking = getAutomatedFlowErrorTracking();
        String emailToCaseErrorTrackingType = getEmailToCaseErrorTrackingType();
        Boolean emailToCaseErrorTrackingAvailable = getEmailToCaseErrorTrackingAvailable();
        Boolean emailToCaseErrorTracking = setEmailToCaseTracking(incomingValue);


        return getEmailServiceData(flowErrorTracking, emailToCaseErrorTracking, emailToCaseErrorTrackingType, emailToCaseErrorTrackingAvailable);
    }

    public static Map<String, Object> flowErrorTracking(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        setAutomatedFlowErrorTracking(Boolean.valueOf(input.get(ConfigUtil.CONFIRM_EMAIL_SERVICE_KEY_VALUE)));

        return getEmailServiceData();
    }

    private static Id getEmailHandlerApexClassId() {
        List<ApexClass> availableClasses = [
            SELECT Id
            FROM ApexClass
            WHERE Name = :ConfigUtil.EMAIL_SERVICE_HANDLER_NAME AND NamespacePrefix = :ConfigUtil.NS];
        if (availableClasses.size() != 1) {
            throw new AdminServiceException('' + ConfigUtil.NS + ConfigUtil.EXCEPTION_ERROR_EMAIL_HANDLER_NOT_FOUND);
        }
        return availableClasses[0].Id;
    }

    public class QuickStartStateWrapper {
        public Boolean connectApp;
        public Boolean connectOrg;
        public Boolean quickTest;
        public Boolean jira;
        public Boolean slack;
        public Boolean teams;
        public Boolean monitoring;
        public Boolean monitoringTestInProgress;
        public Boolean isPassthrough;
        public Boolean useTeams;
        public Boolean useSlack;

        public QuickStartStateWrapper() {
            this.connectApp = false;
            this.connectOrg = false;
            this.quickTest = false;
            this.jira = false;
            this.slack = false;
            this.teams = false;
            this.monitoring = false;
            this.monitoringTestInProgress = false;
            this.isPassthrough = false;
            this.useTeams = false;
            this.useSlack = false;
        }
    }

    public static QuickStartStateWrapper setQuickStartState(Object data) {
        if(data != null) {
            QuickStartStateWrapper state = (QuickStartStateWrapper)JSON.deserialize(JSON.serialize(data), QuickStartStateWrapper.class);
            if(state != null) {
                ConfigUtil.SETTINGS.Quick_Start_State__c = JSON.serialize(state);
                update ConfigUtil.SETTINGS;
            }
        }
        return getQuickStartState();
    }

    public static QuickStartStateWrapper getQuickStartState() {
        QuickStartStateWrapper result = new QuickStartStateWrapper();
        String state = ConfigUtil.SETTINGS.Quick_Start_State__c;
        if(String.isNotBlank(state)) {
            result = (QuickStartStateWrapper)JSON.deserialize(state, QuickStartStateWrapper.class);
        }
        return result;
    }

    public static Object resetAllSettingsForRefreshSandbox() {
        Set<String> setRemoteSiteSettingsNames = new Set<String>();
        for (RemoteSiteSettingsWrapper rss : getRemoteSiteSettings()) {
            setRemoteSiteSettingsNames.add(rss.SiteName);
        }
        List<String> lstRemoteSiteSettingsToDelete = new List<String>();
        List<Connected_Org__c> connectedOrgsList = ConnectedOrgService.getConnectedOrgsList();
        for (Connected_Org__c corg : connectedOrgsList) {
            if (setRemoteSiteSettingsNames.contains(CONNECTED_ORG_REMOTE_SITE_SETTINGS_NAME + corg.Name.left(15))) {
                lstRemoteSiteSettingsToDelete.add(ConfigUtil.prefixCurrentOrgNamespace(CONNECTED_ORG_REMOTE_SITE_SETTINGS_NAME + corg.Name.left(15)));
            }
        }
        Set<String> setDefaultRemoteSiteSettingsNames = new Set<String>();
        setDefaultRemoteSiteSettingsNames.add(BASE_REMOTE_SITE_SETTINGS_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_WEB_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_API_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_API_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_API_NAME);
        setDefaultRemoteSiteSettingsNames.add(ConfigUtil.REMOTE_SITE_SETTINGS_PAGER_DUTY_EVENT_API_NAME);

        for (String defaultRemoteSiteSettingsName : setDefaultRemoteSiteSettingsNames) {
            if (setRemoteSiteSettingsNames.contains(defaultRemoteSiteSettingsName)) {
                lstRemoteSiteSettingsToDelete.add(ConfigUtil.prefixCurrentOrgNamespace(defaultRemoteSiteSettingsName));
            }
        }

        // Remove all remote site settings generated by pharos, no more then 10 records per callout
        if(!lstRemoteSiteSettingsToDelete.isEmpty()) {
            List<List<String>> chunks = doListPartition(lstRemoteSiteSettingsToDelete, 9);
            for(List<String> chunk : chunks) {
                deleteRemoteSiteSettingsMetadata(chunk);
            }
        }

        // Remove all connected orgs, including self
        delete connectedOrgsList;

        // clear QS state
        ConfigUtil.SETTINGS.Quick_Start_State__c = null;
        upsert ConfigUtil.SETTINGS;

        ConfigUtil.CONNECTED_ORGS_SETTINGS.Instance_Url__c = null;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Service_Scheduler_Enabled__c = false;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c = false;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c = null;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Secret__c = null;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c = null;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Name__c = null;
        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;

        ConfigUtil.JIRA_SETTINGS.Jira_API_Url__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_Username__c = null;
        ConfigUtil.JIRA_SETTINGS.Refresh_Token__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token2__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token3__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token4__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token5__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token6__c = null;
        upsert ConfigUtil.JIRA_SETTINGS;

        ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c = null;
        ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c = false;
        ConfigUtil.SLACK_SETTINGS.Slack_Channel_ID__c = null;
        upsert ConfigUtil.SLACK_SETTINGS;

        return true;
    }

    public static List<List<String>> doListPartition(List<String> items, Integer splitSize){
        List<List<String>> result = new List<List<String>>();
        List<String> protoList = items.clone();
        protoList.clear();
        List<String> tempList = protoList.clone();
        Integer index = 0, count = 0, size = items.size();
        while(index < size) {
            tempList.add(items.get(index++));
            ++count;
            if(count == splitSize) {
                result.add(tempList);
                tempList = protoList.clone();
                count = 0;
            }
        }
        if(!tempList.isEmpty()) {
            result.add(tempList);
        }
        return result;
    }

    public static void deleteRemoteSiteSettingsMetadata(String name) {
        for (RemoteSiteSettingsWrapper rss : getRemoteSiteSettings()) {
            if (rss.SiteName == (CONNECTED_ORG_REMOTE_SITE_SETTINGS_NAME + name.left(15))) {
                deleteRemoteSiteSettingsMetadata(new List<String>{ConfigUtil.prefixCurrentOrgNamespace(rss.SiteName)});
                break;
            }
        }
    }

    public static void deleteRemoteSiteSettingsMetadata(List<String> rssList) {
        MetadataService.MetadataPort service = createMetadataPort();

        List<MetadataService.DeleteResult> results = service.deleteMetadata(
            'RemoteSiteSetting', rssList);
        handleDeleteResults(results[0]);
    }

    public static Boolean isRemoteSiteSettingsSetupCompleted() {
        return checkRemoteSiteSettings();
    }

    public static Boolean isLogObjectAccessSetupCompleted() {
        // Log Object Access
        Integer availableAssignmentsToPermissionSets = [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name IN (:ConfigUtil.LOG_READ_PERMISSION_SET_NAME, :ConfigUtil.LOG_READ_WRITE_PERMISSION_SET_NAME)
            LIMIT 1
        ];
        return availableAssignmentsToPermissionSets > 0;
    }

    public static Boolean isEmailServiceFunctionSetupCompleted() {
        // Email Service
        List<EmailServicesFunction> availableEmailServices = getPackageEmailServicesFunctions();
        String emailServiceAddress = getPackageEmailServiceFunctionEmailAddress();

        return !availableEmailServices.isEmpty()
            && availableEmailServices.get(0).IsActive
            && String.isNotBlank(emailServiceAddress);
    }

    public static Boolean isConnectionOrgsSetupCompleted() {
        return !ConnectedOrgService.getConnectedOrgsList().isEmpty();
    }

    public static Integer getIntegrationsPercentCompleted() {
        // Integrations
        Integer integrationsPercent = 0;
        Integer integrationsAvailable = (PermissionsUtil.JiraIntegrationEnabled ? 1 : 0)
            + (PermissionsUtil.SlackIntegrationEnabled ? 1 : 0)
            + (PermissionsUtil.PagerDutyIntegrationEnabled ? 1 : 0)
            + (PermissionsUtil.SplunkIntegrationEnabled ? 1 : 0);

        if (String.isNotBlank(ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c) && ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c && PermissionsUtil.SlackIntegrationEnabled) {
            integrationsPercent += 100/integrationsAvailable;
        }
        if (String.isNotBlank(ConfigUtil.JIRA_OAUTH_TOKEN) && String.isNotBlank(ConfigUtil.JIRA_API_URL) && PermissionsUtil.JiraIntegrationEnabled) {
            integrationsPercent += 100/integrationsAvailable;
        }
        if (String.isNotBlank(ConfigUtil.SPLUNK_SETTINGS.Splunk_Url__c) && ConfigUtil.SPLUNK_SETTINGS.Splunk_Enabled__c && PermissionsUtil.SplunkIntegrationEnabled) {
            integrationsPercent += 100/integrationsAvailable;
        }
        if (String.isNotBlank(ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_API_Token__c) && ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_Enabled__c && PermissionsUtil.PagerDutyIntegrationEnabled) {
            integrationsPercent += 100/integrationsAvailable;
        }
        return integrationsPercent;
    }

    public static Decimal getErrorTrackingPercentCompleted() {
        Boolean emailToCaseErrorTrackingAvailable = getEmailToCaseErrorTrackingAvailable();
        Boolean flowErrorTracking = getAutomatedFlowErrorTracking();
        String emailServiceAddress = getPackageEmailServiceFunctionEmailAddress();
        Decimal percentComplete = 0;
        if(emailToCaseErrorTrackingAvailable) {
            percentComplete += (String.isNotBlank(emailServiceAddress)) ? 33.33 : 0;
            percentComplete += (flowErrorTracking) ? 33.33 : 0;
            percentComplete += (ConfigUtil.SETTINGS.Enable_Email_To_Case_Error_Tracking__c == ENABLE_EMAIL_TO_CASE_ERROR_TRACKING_STATUS_ENABLED) ? 33.33 : 0;
        }
        else {
            percentComplete += (String.isNotBlank(emailServiceAddress)) ? 50 : 0;
            percentComplete += (flowErrorTracking) ? 50 : 0;
        }
        return percentComplete;
    }

    public static Boolean isNotificationsSetupCompleted() {
        List<MonitoringUtil.MonitoringRule> notificationRules = MonitoringUtil.getNotificationRules(null);
        return !notificationRules.isEmpty();
    }

    public static Boolean isPlatformEventConfigSetupCompleted() {
        PlatformEventSubscriberConfigWrapper subscriberConfig = getPlatformEventSubscriberConfig(true);
        Boolean platformEventConfigEnabled = subscriberConfig != null
            && String.isNotBlank(subscriberConfig.Id)
            && String.isNotBlank(subscriberConfig.userId)
            && String.isNotBlank(subscriberConfig.PlatformEventConsumerId);
        return platformEventConfigEnabled;
    }

    public static Boolean isMonitoringRulesSetupCompleted() {
        List<Rule__c> availableMonitoringRules = [SELECT Id FROM Rule__c WHERE Active__c = true AND Type__c = :MonitoringUtil.RULE_TYPE_MONITORING LIMIT 1];
        return (availableMonitoringRules.size() > 0 && PermissionsUtil.MonitoringEnabled);
    }

    public static Boolean isArchivalRulesSetupCompleted() {
        List<Rule__c> availableMonitoringRules = [SELECT Id FROM Rule__c WHERE Active__c = true AND Type__c = :MonitoringUtil.RULE_TYPE_ARCHIVAL LIMIT 1];
        return (availableMonitoringRules.size() > 0 && PermissionsUtil.ArchivalEnabled);
    }

    public static Map<String, Object> getConfigurationOverviewData() {
        Map<String, Object> data = new Map<String, Object>{
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG0 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG1 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG2 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG3 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG4 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG5 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG6 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG7 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG8 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG9 => false,
            ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS => 0
        };


        if (isRemoteSiteSettingsSetupCompleted()) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG0, true);
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
        }

        if (isLogObjectAccessSetupCompleted()) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG1, true);
        }

        if (isEmailServiceFunctionSetupCompleted()) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG2, true);
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
        }

        if (isConnectionOrgsSetupCompleted()) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG3, true);
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PASSTHROUGHT_MODE_ENABLED, ConfigUtil.CONNECTED_ORGS_SETTINGS.Passthrought_Mode__c);
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
        }

        // Add percents for Integrations
        Integer integrationsPercentCompleted = getIntegrationsPercentCompleted();
        if (integrationsPercentCompleted > 0) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG4, true);
        }

        // Sensitive Data Masking
        Integer availableMasks = SensitiveDataMask__c.getAll().size();
        if (availableMasks > 0 && PermissionsUtil.SensitiveDataMaskingEnabled) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG5, true);
        }

        // Monitoring
        if (ConfigUtil.SETTINGS.Monitoring_Enabled__c) {
            if (isMonitoringRulesSetupCompleted()) {
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG6, true);
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
            }
        }
        // Log Retention
        if (ConfigUtil.SETTINGS.Archival_Enabled__c) {
            if (isArchivalRulesSetupCompleted()) {
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG7, true);
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
            }
        }

        if (isPlatformEventConfigSetupCompleted()) {
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG8, true);
            data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
        }

        // Notifications section
        if (PermissionsUtil.NotificationIntegrationEnabled) {
            if (isNotificationsSetupCompleted()) {
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_FLAG9, true);
                data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, ((Integer)data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)) + 1);
            }
        }

        // FLAG0 FLAG2 FLAG3 FLAG4 FLAG6 FLAG7 FLAG8 FLAG9
        Integer flagsQuantity = 8;
        Decimal progress = 100*Decimal.valueOf(String.valueOf(data.get(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS)))/flagsQuantity + (Decimal.valueOf(100)/flagsQuantity)*(Decimal.valueOf(integrationsPercentCompleted)/100);
        data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_PROGRESS, progress <= 100 ? Integer.valueOf(progress) : 100);
        data.put(ConfigUtil.CONFIGURATION_OVERVIEW_DATA_KEY_INTEGRATION_PROGRESS, integrationsPercentCompleted);
        data.put('emailServicePercentComplete', getErrorTrackingPercentCompleted().round(System.RoundingMode.CEILING));

        JiraService.validateAndRefreshJiraOauthToken();

        runServiceScheduler();

        // create default Configs if not exists
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        if(defaultJiraAction == null) {
            ConfigUtil.createDefaultJiraAction();
        }

        if(String.isBlank(ConfigUtil.SETTINGS.Namespace__c)) {
            ConfigUtil.SETTINGS.Namespace__c = ConfigUtil.nameSpacePrefix;
            upsert ConfigUtil.SETTINGS;
        }

        return data;
    }

    public static void runServiceScheduler() {
        if (ConfigUtil.SETTINGS.Service_Scheduler_Enabled__c == true) {
            runScheduler(
                ConfigUtil.PHAROS_LOG_SERVICE_SCHEDULER_NAME,
                ConfigUtil.PHAROS_SETTINGS.Log_Service_Scheduler_Cron_Exp__c,
                ConfigUtil.PHAROS_LOG_SERVICE_SCHEDULER_CRON_EXP,
                new LogServiceScheduler()
            );
        }
    }

    public static void runJiraResolutionBatchScheduler() {
        runScheduler(ConfigUtil.JIRA_RESOLUTION_SCHEDULER_NAME,
            ConfigUtil.PHAROS_SETTINGS.Jira_Scheduler_Cron_Exp__c,
            ConfigUtil.JIRA_RESOLUTION_SCHEDULER_CRON_EXPR,
            new JiraResolutionBatch()
        );
    }

    public static void stopJiraResolutionBatchScheduler() {
        stopScheduler(ConfigUtil.JIRA_RESOLUTION_SCHEDULER_NAME);
    }

    public static void runArchivalScheduler() {
        runScheduler(ConfigUtil.ARCHIVAL_SCHEDULER_NAME,
            ConfigUtil.PHAROS_SETTINGS.Archival_Scheduler_Cron_Exp__c,
            ConfigUtil.ARCHIVAL_SCHEDULER_CRON_EXPR,
            new MonitoringBatch(MonitoringBatch.BATCH_MODE.ARCHIVAL)
        );
    }

    public static void stopArchivalScheduler() {
        stopScheduler(ConfigUtil.ARCHIVAL_SCHEDULER_NAME);
    }

    public static void stopServiceScheduler() {
        stopScheduler(ConfigUtil.PHAROS_LOG_SERVICE_SCHEDULER_NAME);
    }

    public static void stopScheduler(String schedulerJobName) {
        List<CronTrigger> availableCrons = getAvailableCronJobByName(schedulerJobName);
        if (availableCrons.size() == 1) {
            System.abortJob(availableCrons[0].Id);
        }
    }

    public static void runScheduler(String schedulerJobName, String configCronExpr, String defaultCronExpr, Schedulable schedulableInstance) {
        List<CronTrigger> availableCrons = getAvailableCronJobByName(schedulerJobName);
        if (availableCrons.size() == 0) {
            String cronExpr = (String.isNotBlank(configCronExpr))
                ? configCronExpr
                : defaultCronExpr;
            Id cronId = system.schedule(schedulerJobName, cronExpr, schedulableInstance);
        }
    }

    public static List<CronTrigger> getAvailableCronJobByName(String jobName) {
        List<CronTrigger> availableCronJobs = [
            SELECT Id, CronExpression, CronJobDetail.Name, EndTime, NextFireTime, PreviousFireTime, StartTime, State, TimesTriggered
            FROM CronTrigger
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];
        return availableCronJobs;
    }

    public static Object resetTimerForNewConnectedApp() {
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c = null;
        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;
        return new Map<String, String>();
    }

    public static List<Object> getTeams() {
        return GraphAPIService.getTeams();
    }

    public static List<Object> getTeamChannels(String teamId) {
        return GraphAPIService.getChannels(teamId);
    }

    public static TeamsSettings setTeamsSettings(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        ConfigUtil.GRAPH_API_SETTINGS.Enabled__c = Boolean.valueOf(input.get('enabled'));
        upsert ConfigUtil.GRAPH_API_SETTINGS;
        return getTeamsSettings();
    }

    public static TeamsSettings getTeamsSettings() {
        TeamsSettings teamsSettings = new TeamsSettings(ConfigUtil.GRAPH_API_SETTINGS);

        OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GraphAPIService.GRAPH_API_SETTINGS_NAME);
        if(mdtSettings != null) {
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_RESPONSE_TYPE, GraphAPIService.GRAPH_API_TOKEN_RESPONSE_TYPE_CODE);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, LoggerSettingsController.PHAROS_OUATH_CALLBACK_PROXY);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_RESPONSE_MODE, GraphAPIService.GRAPH_API_TOKEN_RESPONSE_MODE_QUERY);
            bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, GraphAPIService.GRAPH_API_SCOPE);

            Map<String, Object> state = new Map<String, Object>{
                'redirectUrl' => ConfigUtil.URL_VF_CALLBACK_PAGE_SETTINGS,
                'isGraphDelegated' => true
            };

            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_STATE, EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state))));
            teamsSettings.oAuthEndpoint = GraphAPIService.GRAPH_API_AUTHORIZE_ENDPOINT + bodyParams.toStringParameters('?');
        }
        return teamsSettings;
    }

    public static ChangeTrackingSettings getChangeTrackingSettings() {
        ChangeTrackingSettings settings = new ChangeTrackingSettings(ConfigUtil.CHANGE_TRACKING_SETTINGS);
        return settings;
    }

    public static ChangeTrackingSettings setChangeTrackingSettings(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        if(input.get('gitChangeTracking') != null) {
            ConfigUtil.CHANGE_TRACKING_SETTINGS.Git_Change_Tracking__c = Boolean.valueOf(input.get('gitChangeTracking'));
        }
        upsert ConfigUtil.CHANGE_TRACKING_SETTINGS;
        return getChangeTrackingSettings();
    }

    public static GitHubSettings resetGitHubSettings() {
        ConfigUtil.GIT_API_SETTINGS.Token__c = null;
        ConfigUtil.GIT_API_SETTINGS.oAuth_Token__c = null;
        ConfigUtil.GIT_API_SETTINGS.Username__c = null;
        ConfigUtil.GIT_API_SETTINGS.Reponame__c = null;
        ConfigUtil.GIT_API_SETTINGS.Branch_Name__c = null;
        ConfigUtil.GIT_API_SETTINGS.Last_Processed_Id__c = null;
        upsert ConfigUtil.GIT_API_SETTINGS;
        return getGitHubSettings();
    }

    public static GitHubSettings setGitHubSettings(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        if(input.get('enabled') != null) {
            ConfigUtil.GIT_API_SETTINGS.Enabled__c = Boolean.valueOf(input.get('enabled'));
        }
        ConfigUtil.GIT_API_SETTINGS.Token__c = input.get('apiToken') != null ? String.valueOf(input.get('apiToken')) : null;
        if(String.isNotBlank(ConfigUtil.GIT_API_SETTINGS.Token__c)
            && ConfigUtil.GIT_API_SETTINGS.Username__c == null) {
            GitHubUtils.GitUserInfo userInfo = GitHubUtils.getGitUserInfo('token ' + ConfigUtil.GIT_API_SETTINGS.Token__c);
            ConfigUtil.GIT_API_SETTINGS.Username__c = userInfo.login;
        }
        ConfigUtil.GIT_API_SETTINGS.Reponame__c = input.get('reponame') != null ? String.valueOf(input.get('reponame')) : null;
        ConfigUtil.GIT_API_SETTINGS.Branch_Name__c = input.get('branchName') != null ? String.valueOf(input.get('branchName')) : null;
        upsert ConfigUtil.GIT_API_SETTINGS;
        return getGitHubSettings();
    }

    public static GitHubSettings getGitHubSettings() {
        GitHubSettings gitSettings = new GitHubSettings(ConfigUtil.GIT_API_SETTINGS);

        OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GitHubUtils.GIT_API_SETTINGS_NAME);
        if(mdtSettings != null) {
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, LoggerSettingsController.PHAROS_OUATH_CALLBACK_PROXY);
            bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, mdtSettings.Scope__c);

            Map<String, Object> state = new Map<String, Object>{
                'redirectUrl' => ConfigUtil.URL_VF_CALLBACK_PAGE_SETTINGS,
                'isGitAPI' => true
            };

            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_STATE, EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state))));
            gitSettings.oAuthEndpoint = GitHubUtils.GIT_API_AUTHORIZE_ENDPOINT + bodyParams.toStringParameters('?');
        }
        return gitSettings;
    }

    public static JiraSettings getJiraSettings() {
        return getJiraSettings(true);
    }

    public static JiraSettings getJiraSettings(Boolean withJiraProjects) {
        Map<String, Object> data = new Map<String, Object>{};
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();

        JiraSettings jiraSettings = new JiraSettings(ConfigUtil.JIRA_SETTINGS, defaultJiraAction);

        if (ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c != null
            && String.isNotBlank(ConfigUtil.JIRA_OAUTH_TOKEN)
            && ConfigUtil.JIRA_SETTINGS.Jira_Username__c != null) {

            try {
                jiraSettings.projectsData = JiraService.getProjects();
                jiraSettings.jiraPriorities = JiraService.getPriorities();
                jiraSettings.isConnectionValid = true;
            } catch(Exception e) {
                jiraSettings.projectsData = e.getMessage();
                jiraSettings.isConnectionValid = false;
            }
        } else {
            jiraSettings.isConnectionValid = false;
        }
        OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance('Jira');
        if(mdtSettings != null) {
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, mdtSettings.Scope__c);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, LoggerSettingsController.PHAROS_OUATH_CALLBACK_PROXY);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_RESPONSE_TYPE, HttpUtils.HTTP_URL_PARAM_CODE);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_PROMPT, HttpUtils.HTTP_URL_PARAM_PROMPT_CONSENT);
            bodyParams.addParameter(HttpUtils.HTTP_URL_PARAM_AUDIENCE, HttpUtils.HTTP_URL_PARAM_AUDIENCE_JIRA_API);

            Map<String, Object> state = new Map<String, Object>{
                'redirectUrl' => System.Url.getSalesforceBaseUrl().toExternalForm() + '/apex/' + ConfigUtil.getNameSpacePrefix() + 'Settings',
                'isJira' => true
            };

            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_STATE, EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(state))));
            jiraSettings.oAuthEndpoint = ConfigUtil.JIRA_CLOUD_AUTHORIZE_ENDPOINT + bodyParams.toStringParameters('?');
        }

        return jiraSettings;
    }

    public static Map<String, Object> getCreateMeta(Object createMetaRequestData) {
        try {
            Map<String, Object> ss = (Map<String, Object>)createMetaRequestData;
//          Map<String, Object> ss = (Map<String, Object>)JSON.deserializeUntyped((JSON.serialize(createMetaRequestData)));
            String projectId = (String)ss.get(ConfigUtil.CREATE_META_REQUEST_DATA_KEY_PROJECT_ID);
            String issueTypeId = (String)ss.get(ConfigUtil.CREATE_META_REQUEST_DATA_KEY_ISSUE_TYPE_ID);
            JiraService.CreateMeta meta = null;

            Set<String> projectIds = new Set<String>{projectId};
            Set<String> issueTypeIds = new Set<String>{issueTypeId};

            List<Action__c> jiraTemplates = [
                SELECT id, JIRAProject__c, JIRAIssueType__c
                FROM Action__c
                WHERE Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION OR Action_Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
            ];

            for (Action__c jt : jiraTemplates) {
                projectIds.add(jt.JIRAProject__c);
                issueTypeIds.add(jt.JIRAIssueType__c);
            }

            List<JiraService.JiraProjectMeta> allProjects = JiraService.getProjects();
            for(JiraService.JiraProjectMeta project : allProjects) {
                projectIds.add(project.id);
                if(project.issueTypes != null) {
                    for(JiraService.JiraIssueType issueType : project.issueTypes) {
                        issueTypeIds.add(issueType.id);
                    }
                }
            }

            // clean list of project Ids an issueTypeIds as Action__c can contain null or '' (invalid values)
            projectIds.remove(null);
            projectIds.remove('');
            issueTypeIds.remove(null);
            issueTypeIds.remove('');

//            if (projectIds.size() > 0 && issueTypeIds.size() > 0) {
//                meta = JiraService.getIssueMeta(new List<String>(projectIds), new List<String>(issueTypeIds));
//            }
            Map<String, JiraService.CreateMetaField> customFields = JiraService.getIssueMetaCustomFields(new List<String>(projectIds), new List<String>(issueTypeIds));

            List<JiraService.JiraComponent> components = JiraService.getProjectComponents(projectId);
            List<JiraService.Epic> epics;
            try {
                epics = JiraService.getEpics(projectId);
            }
            catch(Exception e) {
                epics = new List<JiraService.Epic>();
            }

            Map<String, Object> output = new Map<String, Object>{
//                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_META => meta,
                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_META => customFields,
                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_LOG_FIELDS => getLogFieldsForJiraMapping(),
                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_COMPONENTS => components,
                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_EPICS => epics,
                ConfigUtil.CREATE_META_REQUEST_DATA_KEY_FIELDS_MAPPING => ConfigUtil.JIRA_FIELDS_MAPPINGS.jira_fields_mapping
            };
            return output;
        }
        catch(Exception e){
            Logger.getInstance().internalError(e, null, true, AdminService.class.getName(), 'getCreateMeta');
        }
        return null;
    }

    public static Object saveJiraFieldsMapping(Object inputData) {
        List<ConfigUtil.JiraFieldsMapping> fieldsMapping = (List<ConfigUtil.JiraFieldsMapping>)JSON.deserialize(JSON.serialize(inputData), List<ConfigUtil.JiraFieldsMapping>.class);
        ConfigUtil.setJiraFieldsMappings(fieldsMapping);
        return ConfigUtil.SAVE_JIRA_FIELDS_MAPPINGS_SUCCESS;
    }

    public static Object getLogFieldsForJiraMapping() {
        List<Map<String, String>> result = new List<Map<String, String>>();

        SObjectType logType = ConfigUtil.MAP_GD.get(Log__c.getSObjectType().getDescribe().getName());
        Map<String,Schema.SObjectField> mfields = logType.getDescribe().fields.getMap();
        List<String> fieldKeys = (new List<String>(mfields.keySet()));
        for (String k : fieldKeys) {
            if(!FILTERS_EXCLUDE_LOG_FIELDS.contains(k.toLowerCase())) {
                result.add(new Map<String, String>{
                    ConfigUtil.PICKLIST_KEY_VALUE => mfields.get(k).getDescribe().getName(),
                    ConfigUtil.PICKLIST_KEY_LABEL => mfields.get(k).getDescribe().getLabel()
                });
            }
        }

        return result;
    }

    public static final Set<String> FILTERS_EXCLUDE_LOG_FIELDS = new Set<String>{
        Schema.sObjectType.Log__c.fields.Deploy_Results__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Setup_Audit_Trail__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Pending_Jobs__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Total_Pending_Jobs__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Total_Active_Sessions__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Installed_Packages__c.getName().toLowerCase(),
        Schema.sObjectType.Log__c.fields.Stacktrace_Parse_Result__c.getName().toLowerCase()
    };

    public static Object getLogFields() {
        List<Map<String, String>> result = new List<Map<String, String>>();

        SObjectType logType = ConfigUtil.MAP_GD.get(Log__c.getSObjectType().getDescribe().getName());
        Map<String,Schema.SObjectField> mfields = logType.getDescribe().fields.getMap();
        List<String> fieldKeys = (new List<String>(mfields.keySet()));
        for (String k : fieldKeys) {
            if(!FILTERS_EXCLUDE_LOG_FIELDS.contains(k.toLowerCase())) {
                result.add(new Map<String, String>{
                    ConfigUtil.PICKLIST_KEY_VALUE => mfields.get(k).getDescribe().getName(),
                    ConfigUtil.PICKLIST_KEY_LABEL => mfields.get(k).getDescribe().getLabel(),
                    ConfigUtil.PICKLIST_KEY_TYPE => String.valueOf(mfields.get(k).getDescribe().getType())
                });
            }
        }

        return result;
    }

    public static Object getJiraProjectUsers(String projectId) {
        Object users = JiraService.getProjectAssignableUsers(projectId);
        return users;
    }

    public static String saveJiraSettings(Object jiraSettingsObject) {
        JiraSettings jiraSettings = (JiraSettings)JSON.deserialize(JSON.serialize(jiraSettingsObject), JiraSettings.class);
        ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c = jiraSettings.baseUrl;
        if (String.isNotBlank(jiraSettings.apiToken) && jiraSettings.apiToken != ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c) {
            ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = jiraSettings.apiToken;
        }
        ConfigUtil.JIRA_SETTINGS.Jira_Username__c = jiraSettings.username;
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_NAME, jiraSettings.baseUrl, ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_DESCRIPTION);
        upsert ConfigUtil.JIRA_SETTINGS;
        runJiraResolutionBatchScheduler();
        return ConfigUtil.SAVE_JIRA_SETTINGS_SUCCESS;
    }

    public static String saveJiraSettings2(Object jiraSettingsObject) {
        Map<String, Object> ss = (Map<String, Object>)JSON.deserializeUntyped((JSON.serialize(jiraSettingsObject)));
        JiraSettings jiraSettings = (JiraSettings)JSON.deserialize(JSON.serialize(ss), JiraSettings.class);
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        defaultJiraAction.JIRAProject__c = jiraSettings.jiraproject;
        defaultJiraAction.JIRAIssueType__c = jiraSettings.jiraissuetype;
        defaultJiraAction.JIRAAssignee__c = jiraSettings.jiraassignee;
        defaultJiraAction.JIRAAssignee_Id__c = jiraSettings.jiraassigneeid;
        defaultJiraAction.JIRAComponents__c = jiraSettings.jiracomponents;
        defaultJiraAction.JIRAEpic__c = jiraSettings.jiraepic;
        defaultJiraAction.JIRALabels__c = jiraSettings.jiralabels;
        defaultJiraAction.JIRAPriority__c = jiraSettings.jirapriority;
        defaultJiraAction.Subject__c = jiraSettings.subject;
        defaultJiraAction.Body__c = jiraSettings.body;
        update defaultJiraAction;


        ConfigUtil.JIRA_SETTINGS.Auto_Generate_Similarity_Labels__c = jiraSettings.autoJiraTaskLabelsFromHashes;
        ConfigUtil.JIRA_SETTINGS.Auto_Relate_Tickets_With_Similar_Errors__c = jiraSettings.autoRelateTicketsWithSimilarErrors;
        ConfigUtil.JIRA_SETTINGS.Create_Unique_Tickets_by_Org__c = jiraSettings.createUniqueTicketsByOrg;

        upsert ConfigUtil.JIRA_SETTINGS;

        return ConfigUtil.SAVE_JIRA_SETTINGS_SUCCESS;
    }

    public static String resetJiraSettings() {
        ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_API_Token__c = null;
        ConfigUtil.JIRA_SETTINGS.Jira_Username__c = null;
        ConfigUtil.JIRA_SETTINGS.Auto_Generate_Similarity_Labels__c = false;
        upsert ConfigUtil.JIRA_SETTINGS;

        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        defaultJiraAction.JIRAProject__c = null;
        defaultJiraAction.JIRAIssueType__c = null;
        defaultJiraAction.JIRAAssignee__c = null;
        defaultJiraAction.JIRAAssignee_Id__c = null;
        defaultJiraAction.JIRAComponents__c = null;
        defaultJiraAction.JIRAEpic__c = null;
        defaultJiraAction.JIRALabels__c = null;
        update defaultJiraAction;
        stopJiraResolutionBatchScheduler();
        return ConfigUtil.SAVE_JIRA_SETTINGS_SUCCESS;
    }

    public static SplunkSettings getSplunkSettings() {
        SplunkSettings splunkSettings = new SplunkSettings(ConfigUtil.SPLUNK_SETTINGS);
        List<String> availableSplunkFields = ConfigUtil.getAvailableSplunkFields();

        SObjectType logType = ConfigUtil.MAP_GD.get(Log__c.getSObjectType().getDescribe().getName());
        Map<String,Schema.SObjectField> mfields = logType.getDescribe().fields.getMap();

        List<Map<String, String>> fieldsProcessed = new List<Map<String, String>>();
        for (String k : availableSplunkFields) {
            fieldsProcessed.add(new Map<String, String>{
                ConfigUtil.PICKLIST_KEY_NAME => mfields.get(k).getDescribe().getName(),
                ConfigUtil.PICKLIST_KEY_LABEL => mfields.get(k).getDescribe().getLabel()
            });
        }
        splunkSettings.logFields = fieldsProcessed;
        splunkSettings.config = SplunkService.getLogFieldsForSplunk();
        return splunkSettings;
    }

    public static SplunkSettings generateSplunkToken(Object indataObj) {
        Map<String, Object> indata = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(indataObj));
        String token = SplunkService.generateToken((String)indata.get('username'), (String)indata.get('password'));
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Token__c = token;
        upsert ConfigUtil.SPLUNK_SETTINGS;
        ConfigUtil.initSplunkSettings();

        return getSplunkSettings();
    }

    public static Boolean sendMessageToSplunk(Object indataObj) {
        Map<String, Object> indata = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(indataObj));
        SplunkService.sendMessage((String)indata.get(ConfigUtil.SEND_SPLUNK_MESSAGE_KEY_MESSAGE));
        return true;
    }

    public static Boolean validateSplunkEventCollectorConnection(Object indataObj) {
        Map<String, Object> indata = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(indataObj));
        SplunkService.sendLog(new List<Log__c>{new Log__c(Summary__c = 'Test Log Message From "Pharos" App.')});
        return true;
    }

    public static SplunkSettings saveSplunkSettings(Object splunkSettingsObject) {
        SplunkSettings indata = (SplunkSettings)JSON.deserialize(JSON.serialize(splunkSettingsObject), SplunkSettings.class);
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_WEB_NAME, indata.url, ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_WEB_DESCRIPTION);
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_API_NAME, indata.url + ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_API_PORT, ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_API_DESCRIPTION);
        upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_NAME, indata.url + ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_PORT, ConfigUtil.REMOTE_SITE_SETTINGS_SPLUNK_EVENT_COLLECTOR_DESCRIPTION);
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Enabled__c = indata.enabled;
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Url__c = indata.url;
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Token__c= indata.token;
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Event_Collector_Token__c= indata.ecToken;
        upsert ConfigUtil.SPLUNK_SETTINGS;

        ConfigUtil.setSplunkFields(indata.config);
        ConfigUtil.initSplunkFields();
        ConfigUtil.initSplunkSettings();

        return getSplunkSettings();
    }

    public static SplunkSettings setSplunkSettings(Object splunkData) {
        Map<String, Object> indata = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(splunkData));
        ConfigUtil.SPLUNK_SETTINGS.Splunk_Enabled__c = (Boolean)indata.get('enabled');
        upsert ConfigUtil.SPLUNK_SETTINGS;
        return getSplunkSettings();
    }

    public static OAuthSettings getOAuthSettings() {
        OAuthSettings oauthSettings = new OAuthSettings(ConfigUtil.CONNECTED_ORGS_SETTINGS);
        return oauthSettings;
    }

    public static OAuthSettings saveConnecterAppDetails(Object oauthSettingsObject) {
        OAuthSettings indata = (OAuthSettings)JSON.deserialize(JSON.serialize(oauthSettingsObject), OAuthSettings.class);
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c = indata.clientKey;
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Secret__c = indata.clientSecret;
        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;
        ConfigUtil.initConnectedOrgsSettings();
        return getOAuthSettings();
    }

    public class OAuthSettings {
        public String clientKey;
        public String clientSecret;
        public Boolean connectedAppCreatedLessThan10Mins = false;
        public Boolean schedulerEnabled;

        public OAuthSettings() {}

        public OAuthSettings(Connected_Orgs_Settings__c connectedOrgSettings) {
            this.clientKey = connectedOrgSettings.Client_Key__c;
            this.clientSecret = connectedOrgSettings.Client_Secret__c;
            this.schedulerEnabled = connectedOrgSettings.Service_Scheduler_Enabled__c;
            this.connectedAppCreatedLessThan10Mins = connectedOrgSettings.Connected_App_Created_At__c != null && connectedOrgSettings.Connected_App_Created_At__c > Datetime.now().addMinutes(-10);
        }
    }

    public static LogAccessData getLogAccessData() {
        LogAccessData output = new LogAccessData();
        List<PermissionSet> psList = [
            SELECT Id, Name, NamespacePrefix, Label
            FROM PermissionSet
            WHERE Name = :ConfigUtil.LOG_READ_PERMISSION_SET_NAME AND NamespacePrefix = :ConfigUtil.NS
        ];
        if (psList.size() != 1) {
            throw new AdminServiceException(ConfigUtil.PERMISSIONS_READ_NOT_FOUND_MESSAGE);
        }
        output.readPermissionSet = psList[0];
        psList = [
            SELECT Id, Name, NamespacePrefix, Label
            FROM PermissionSet
            WHERE Name = :ConfigUtil.LOG_READ_WRITE_PERMISSION_SET_NAME AND NamespacePrefix = :ConfigUtil.NS
        ];
        if (psList.size() != 1) {
            throw new AdminServiceException(ConfigUtil.PERMISSIONS_RW_NOT_FOUND_MESSAGE);
        }
        output.readWritePermissionSet = psList[0];
        List<Id> permissionSetIds = new List<Id> {
            output.readPermissionSet.Id,
            output.readWritePermissionSet.Id
        };
        output.assignments = [
            SELECT Id, AssigneeId, Assignee.Name, PermissionSetId, PermissionSet.Name
            FROM PermissionSetAssignment
            WHERE PermissionSetId IN :permissionSetIds
        ];
        return output;
    }

    public static OAuthSettings createConnectedApp(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        Boolean useManagedApp = (Boolean)input.get('useManagedApp');

        if(!useManagedApp) {
            MetadataService.MetadataPort service = createMetadataPort();
            String appName = ConfigUtil.prefixCurrentOrgNamespace(ConfigUtil.CONNECTED_APP_API_NAME);

            MetadataService.ConnectedApp currentConnectedApp =
                (MetadataService.ConnectedApp)service.readMetadata('ConnectedApp', new String[] {appName}).getRecords()[0];
            if(currentConnectedApp.fullName != null) {
                handleDeleteResults(
                    service.deleteMetadata('ConnectedApp', new String[] {appName})[0]);
            }

            String key = generateRandomString(32);
            String secret = generateRandomStringOfNumbers(32);
            String payload = getConnectedAppPayload(secret, key, AdminController.salesforceBaseUrl + ConfigUtil.CONNECTED_APP_CALLBACK_PAGE_URL, ConfigUtil.CONNECTED_APP_NAME, ConfigUtil.CONNECTED_APP_API_NAME);

            MetadataService.ConnectedApp app = (MetadataService.ConnectedApp)JSON.deserialize(payload, MetadataService.ConnectedApp.class);
            List<MetadataService.SaveResult> results =
                service.createMetadata(
                    new MetadataService.Metadata[] { app });
            handleSaveResults(results[0]);

            ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c = key;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Secret__c = secret;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c = Datetime.now();
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Name__c = ConfigUtil.CONNECTED_APP_API_NAME;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Use_Managed_App__c = useManagedApp;
        }
        else {
            OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(ConfigUtil.PHAROS_APP_SETTINGS_NAME);
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c = mdtSettings.Client_Id__c;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Secret__c = mdtSettings.Client_Secret__c;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Created_At__c = Datetime.now().addMinutes(-10);
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Connected_App_Name__c = ConfigUtil.CONNECTED_APP_API_NAME;
            ConfigUtil.CONNECTED_ORGS_SETTINGS.Use_Managed_App__c = useManagedApp;
        }

        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;

        ConfigUtil.initConnectedOrgsSettings();
        return getOAuthSettings();
    }

    public static String getConnectedAppPayload(String secret, String key, String callBackUrl, String name, String apiName) {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :ConfigUtil.METADATA_CONNECTED_APP_PAYLOAD_RESOURCE_NAME LIMIT 1];
        String payload = sr.Body.toString();
        payload = payload.replace('XXXXX1', secret);
        payload = payload.replace('XXXXX2', key);
        payload = payload.replace('XXXXX3', callBackUrl);
        payload = payload.replace('XXXXX4', name);
        payload = payload.replace('XXXXX5', apiName);
        return payload;
    }

    public static void handleDeleteResults(MetadataService.DeleteResult deleteResult) {
        // Nothing to see?
        if(deleteResult==null || deleteResult.success)
            return;
        // Construct error message and throw an exception
        if(deleteResult.errors!=null) {
            List<String> messages = new List<String>();
            messages.add(
                (deleteResult.errors.size()==1 ? 'Error ' : 'Errors ') +
                    'occured processing component ' + deleteResult.fullName + '.');
            for(MetadataService.Error error : deleteResult.errors)
                messages.add(
                    error.message + ' (' + error.statusCode + ').' +
                        ( error.fields!=null && error.fields.size()>0 ?
                            ' Fields ' + String.join(error.fields, ',') + '.' : '' ) );
            if(messages.size()>0)
                throw new AdminServiceException(String.join(messages, ' '));
        }
        if(!deleteResult.success)
            throw new AdminServiceException('Request failed with no specified error.');
    }

    public static void handleSaveResults(MetadataService.SaveResult saveResult) {
        // Nothing to see?
        if(saveResult==null || saveResult.success) {
            return;
        }
        // Construct error message and throw an exception
        if(saveResult.errors!=null) {
            List<String> messages = new List<String>();
            messages.add((saveResult.errors.size() == 1 ? ConfigUtil.HANDLE_SAVE_RESULT_KEY_ERROR : ConfigUtil.HANDLE_SAVE_RESULT_KEY_ERRORS) +
                ConfigUtil.HANDLE_SAVE_RESULT_KEY_COMPONENTS + saveResult.fullName + '.'
            );
            for(MetadataService.Error error : saveResult.errors) {
                messages.add(
                    error.message + ' (' + error.statusCode + ').' +
                    (error.fields != null && error.fields.size() > 0 ?
                        ConfigUtil.HANDLE_SAVE_RESULT_KEY_FIELDS + String.join(error.fields, ',') + '.' : '' ) );
            }
            if(messages.size() > 0) {
                throw new AdminServiceException(String.join(messages, ' '));
            }
        }
        if(!saveResult.success) {
            throw new AdminServiceException(ConfigUtil.FAILED_NO_ERRORS_MESSAGE);
        }
    }

    public static void handleUpsertResults(MetadataService.UpsertResult upsertResult) {
        // Nothing to see?
        if(upsertResult == null || upsertResult.success) {
            return;
        }
        // Construct error message and throw an exception
        if(upsertResult.errors != null) {
            List<String> messages = new List<String>();
            messages.add((upsertResult.errors.size() == 1 ? ConfigUtil.HANDLE_SAVE_RESULT_KEY_ERROR : ConfigUtil.HANDLE_SAVE_RESULT_KEY_ERRORS) +
                    ConfigUtil.HANDLE_SAVE_RESULT_KEY_COMPONENTS + upsertResult.fullName + '.'
            );
            for(MetadataService.Error error : upsertResult.errors) {
                messages.add(
                    error.message + ' (' + error.statusCode + ').' +
                        (error.fields != null && error.fields.size() > 0 ?
                            ConfigUtil.HANDLE_SAVE_RESULT_KEY_FIELDS + String.join(error.fields, ',') + '.' : '' ) );
            }
            if(messages.size() > 0) {
                throw new AdminServiceException(String.join(messages, ' '));
            }
        }
        if(!upsertResult.success) {
            throw new AdminServiceException(ConfigUtil.FAILED_NO_ERRORS_MESSAGE);
        }
    }

    public static String generateRandomString(Integer len) {
        final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < len) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           randStr += chars.substring(idx, idx+1);
        }
        return randStr;
    }

    public static String generateRandomStringOfNumbers(Integer len) {
        final String chars = '0123456789';
        String randStr = '';
        while (randStr.length() < len) {
           Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
           randStr += chars.substring(idx, idx+1);
        }
        return randStr;
    }

    public static List<User> getLogAccessUsers() {
        return [SELECT Id, Name FROM User WHERE IsActive = true];
    }

    public static List<SensitiveDataMaskWrapper> getMasks() {
        List<SensitiveDataMaskWrapper> masks = new List<SensitiveDataMaskWrapper>();
        Map<String, SensitiveDataMask__c> masksMap = SensitiveDataMask__c.getAll();
        if(!masksMap.isEmpty()) {
            for (SensitiveDataMask__c m : masksMap.values()) {
                masks.add(new SensitiveDataMaskWrapper(m));
            }
        }

        return masks;
    }

    public static List<SensitiveDataMaskWrapper> saveMask(Object data) {
        SensitiveDataMaskWrapper input = (SensitiveDataMaskWrapper)JSON.deserialize(JSON.serialize(data), SensitiveDataMaskWrapper.class);
        SensitiveDataMask__c mask = new SensitiveDataMask__c(
            Name = (input.id == null) ? ConfigUtil.generateUUID4() : input.id,
            Regex__c = input.regex,
            Description__c = input.description
        );
        upsert mask Name;
        return getMasks();
    }

    public static List<SensitiveDataMaskWrapper> deleteMask(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        delete [SELECT Id FROM SensitiveDataMask__c WHERE Name = :(String)input.get(ConfigUtil.SENSETIVE_MASK_KEY_ID) LIMIT 1];
        return getMasks();
    }

    public static String testMask(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String text = (String)input.get(ConfigUtil.SENSETIVE_MASK_KEY_TEXT);
        String regex = (String)input.get(ConfigUtil.SENSETIVE_MASK_KEY_REGEX);
        String result = text.replaceAll(regex, ConfigUtil.SENSETIVE_MASK_KEY_MASK);
        return result;
    }

    public static LogAccessData addPermissionSetToUser(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        PermissionSetAssignment newPSA = new PermissionSetAssignment(
            AssigneeId = (String)input.get(ConfigUtil.PERMISSION_SET_KEY_USER_ID),
            PermissionSetId = (String)input.get(ConfigUtil.PERMISSION_SET_KEY_PERMISSION_SET_ID)
        );
        insert newPSA;
        return getLogAccessData();
    }

    public static OAuthSettings manageServiceScheduler(Object oauthSettingsObject) {
        OAuthSettings indata = (OAuthSettings)JSON.deserialize(JSON.serialize(oauthSettingsObject), OAuthSettings.class);
        ConfigUtil.CONNECTED_ORGS_SETTINGS.Service_Scheduler_Enabled__c = indata.schedulerEnabled;
        upsert ConfigUtil.CONNECTED_ORGS_SETTINGS;
        ConfigUtil.initConnectedOrgsSettings();
        if (ConfigUtil.CONNECTED_ORGS_SETTINGS.Service_Scheduler_Enabled__c) {
            runServiceScheduler();
        } else {
            stopServiceScheduler();
        }
        return getOAuthSettings();
    }

    public static LogAccessData removePermissionSetAssignment(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        delete [SELECT Id FROM PermissionSetAssignment WHERE Id = :(String)input.get(ConfigUtil.PERMISSION_SET_ASSIGNMENT_KEY_ID) AND PermissionSet.Name IN (:ConfigUtil.LOG_READ_PERMISSION_SET_NAME, :ConfigUtil.LOG_READ_WRITE_PERMISSION_SET_NAME)];
        return getLogAccessData();
    }

    public static Map<String, Object> getServicesenable() {
        return new Map<String, Object>{
            //'Jira' => ConfigUtil.SETTINGS.Auto_Jira_Task__c,
            ConfigUtil.SLACK_SERVICE_NAME => ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c,
            ConfigUtil.PAGER_DUTY_SERVICE_NAME => ConfigUtil.PAGER_DUTY_SETTINGS.PagerDuty_Enabled__c,
            ConfigUtil.TEAMS_SERVICE_NAME => ConfigUtil.GRAPH_API_SETTINGS.Enabled__c
        };
    }
    //log-categories
    public static Map<String, Object> getLogCategories() {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.LOG_CATEGORIES_KEY_CATEGORIES, SObjectType.Log__c.fields.Category__c.getPicklistValues());
        ret.put(ConfigUtil.LOG_CATEGORIES_KEY_RECORDTYPES, getLogRecordTypePicklistValues());
        ret.put(ConfigUtil.LOG_CATEGORIES_KEY_MAPPINGS, getLogRecordTypeMappings());
        return ret;
    }

    public class SelectOptionWrapper {
        String value;
        String label;

        public SelectOptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class LogRecordTypeMapping {
        public String categoryValue;
        public String categoryLabel;
        public String recordTypeValue;
        public String recordTypeLabel;

        public LogRecordTypeMapping(String categoryValue, String categoryLabel, String recordTypeValue, String recordTypeLabel) {
            this.categoryValue = categoryValue;
            this.categoryLabel = categoryLabel;
            this.recordTypeValue = recordTypeValue;
            this.recordTypeLabel = recordTypeLabel;
        }
    }

    public static String deleteLogRecordTypeMappings(Object payload) {
        return setMappings(payload, true);
    }

    public static String setLogRecordTypeMappings(Object payload) {
        return setMappings(payload, false);
    }

    public static String setMappings(Object payload, Boolean isDelete) {

        List<Sobject> toDelete = new List<Sobject>();
        List<Sobject> toUpdate = new List<Sobject>();
        List<Sobject> toInsert = new List<Sobject>();
        LogRecordTypeMapping mapping = (LogRecordTypeMapping)JSON.deserialize(JSON.serialize(payload), LogRecordTypeMapping.class);
        Map<String, Log_Category_Mapping_Setting__c> records = Log_Category_Mapping_Setting__c.getAll();
        List<Log_Category_Mapping_Setting__c> mappingRecords = records.values();

        Set<String> existMappingRecords = new Set<String>();
        existMappingRecords.add(mapping.categoryValue + mapping.recordTypeValue);

        String categoryValue = mapping.categoryValue;
        String recordTypeValue = mapping.recordTypeValue;
        Boolean haveUpdate = false;
        Boolean existRecord = false;
        for(Log_Category_Mapping_Setting__c categoryMapping : mappingRecords) {
            if(categoryMapping.Category__c != null && categoryMapping.Record_Type_Developer_Name__c != null) {
                String rtDeveloperNameValue = categoryMapping.Record_Type_Developer_Name__c;
                String categoryFieldValue = categoryMapping.Category__c;

                if(categoryValue == categoryFieldValue) {
                    if(recordTypeValue != rtDeveloperNameValue) {
                        categoryMapping.Record_Type_Developer_Name__c = recordTypeValue;
                        toUpdate.add(categoryMapping);
                        haveUpdate = true;
                    }
                    else {
                        existRecord = true;
                        if(isDelete) {
                            toDelete.add(categoryMapping);
                        }
                    }
                }
            }
        }

        if(!haveUpdate && !existRecord) {
            Log_Category_Mapping_Setting__c sObjInsert = new Log_Category_Mapping_Setting__c();
            sObjInsert.Name = categoryValue;
            sObjInsert.Category__c = categoryValue;
            sObjInsert.Record_Type_Developer_Name__c = recordTypeValue;
            toInsert.add(sObjInsert);
        }

        if(!toUpdate.isEmpty()) {
            update toUpdate;
        }
        if(!toInsert.isEmpty()) {
            insert toInsert;
        }
        if(!toDelete.isEmpty()) {
            delete toDelete;
        }

        return ConfigUtil.SAVE_LOG_CATEGORIES_SUCCESS;
    }

    private static List<LogRecordTypeMapping> getLogRecordTypeMappings() {
        List<LogRecordTypeMapping> result = new List<LogRecordTypeMapping>();
        Map<String, Log_Category_Mapping_Setting__c> records = Log_Category_Mapping_Setting__c.getAll();

        for(Log_Category_Mapping_Setting__c record : records.values()) {
            if(record.Category__c != null && record.Record_Type_Developer_Name__c != null) {
                LogRecordTypeMapping mapping = new LogRecordTypeMapping(record.Category__c,record.Category__c,record.Record_Type_Developer_Name__c,record.Record_Type_Developer_Name__c);
                result.add(mapping);
            }
        }
        return result;
    }

    private static List<SelectOptionWrapper> getLogRecordTypePicklistValues() {
        List<SelectOptionWrapper> recordTypes = new List<SelectOptionWrapper>();
        for(String rtLabel : Schema.SObjectType.Log__c.getRecordTypeInfosByName().keySet()) {
            String rtDeveloperName = Schema.SObjectType.Log__c.getRecordTypeInfosByName().get(rtLabel).getDeveloperName();
            SelectOptionWrapper option = new SelectOptionWrapper(rtDeveloperName, rtLabel);
            recordTypes.add(option);
        }
        return recordTypes;
    }

    //Jira
    public static Map<String, Object> getJiraDataSettings(Object data) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.MONITORING_APP_KEY_JIRA_RULES, getJiraRules());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS, SObjectType.Rule__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS, SObjectType.RuleFilter__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_FILTERS, getMonitoringRuleFilters());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTIONS, getJiraActions());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS, getNotificationAssignee());
        ret.put(ConfigUtil.MONITORING_APP_KEY_LOG_FIELDS, getLogFields());
        ret.put(ConfigUtil.MONITORING_APP_KEY_SERVICE_ENABLE, getServicesenable());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTION_TYPES, getActionTypes(MonitoringUtil.RULE_TYPE_MONITORING));
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_SUB_TYPES, SObjectType.Rule__c.fields.SubType__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_USER_TIMEZONE_OFFSET, getUserTimezoneOffset());
        return ret;
    }

    //Archival
    public static Map<String, Object> getArchivalSettings(Object data) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_ENABLED, ConfigUtil.SETTINGS.Archival_Enabled__c);
        ret.put(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_RULES, getArchivalRules());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS, SObjectType.Rule__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS, SObjectType.RuleFilter__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_FILTERS, getMonitoringRuleFilters());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTIONS, getArchivalActions());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS, getNotificationAssignee());
        ret.put(ConfigUtil.MONITORING_APP_KEY_LOG_FIELDS, getLogFields());
        ret.put(ConfigUtil.MONITORING_APP_KEY_SERVICE_ENABLE, getServicesenable());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTION_TYPES, getActionTypes(MonitoringUtil.RULE_TYPE_ARCHIVAL));
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_SUB_TYPES, SObjectType.Rule__c.fields.SubType__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_USER_TIMEZONE_OFFSET, getUserTimezoneOffset());
        return ret;
    }

    //MONITORING
    public static Map<String, Object> getMonitoringSettings(Object data) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.MONITORING_APP_KEY_MONITORING_ENABLED, ConfigUtil.SETTINGS.Monitoring_Enabled__c);
        ret.put(ConfigUtil.MONITORING_APP_KEY_MONITORING_RULES, getMonitoringRules());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS, SObjectType.Rule__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS, SObjectType.RuleFilter__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_FILTERS, getMonitoringRuleFilters());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTIONS, getMonitoringActions());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS, getNotificationAssignee());
        ret.put(ConfigUtil.MONITORING_APP_KEY_LOG_FIELDS, getLogFields());
        ret.put(ConfigUtil.MONITORING_APP_KEY_SERVICE_ENABLE, getServicesenable());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTION_TYPES, getActionTypes(MonitoringUtil.RULE_TYPE_MONITORING));
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_SUB_TYPES, SObjectType.Rule__c.fields.SubType__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_USER_TIMEZONE_OFFSET, getUserTimezoneOffset());
        return ret;
    }

    public static Map<String, Object> getNotificationSettings(Object data) {
        return getNotificationSettings(data, getActionTypes(MonitoringUtil.RULE_TYPE_MONITORING));
    }

    public static Map<String, Object> getNotificationSettings(Object data, Map<String, List<SelectOptionWrapper>> actionTypes) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_ENABLED, PermissionsUtil.NotificationIntegrationEnabled);
        ret.put(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_RULES, getNotificationRules());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS, SObjectType.Rule__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS, SObjectType.RuleFilter__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_FILTERS, getMonitoringRuleFilters());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTIONS, getNotificationActions());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS, getNotificationAssignee());
        ret.put(ConfigUtil.MONITORING_APP_KEY_LOG_FIELDS, getLogFields());
        ret.put(ConfigUtil.MONITORING_APP_KEY_SERVICE_ENABLE, getServicesenable());
        ret.put(ConfigUtil.MONITORING_APP_KEY_ACTION_TYPES, actionTypes);
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_SUB_TYPES, SObjectType.Rule__c.fields.SubType__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_USER_TIMEZONE_OFFSET, getUserTimezoneOffset());
        return ret;
    }

    //Broadcast
    public static Map<String, Object> getBroadcastSettings(Object data) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.MONITORING_APP_KEY_BROADCAST_RULES, getBroadcastRules());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_COMPARISON_OPERATORS, SObjectType.Rule__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_FILTER_COMPARISON_OPERATORS, SObjectType.RuleFilter__c.fields.ComparisonOperator__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_FILTERS, getMonitoringRuleFilters());
        ret.put(ConfigUtil.MONITORING_APP_KEY_LOG_FIELDS, getLogFields());
        ret.put(ConfigUtil.MONITORING_APP_KEY_SERVICE_ENABLE, getServicesenable());
        ret.put(ConfigUtil.MONITORING_APP_KEY_RULE_SUB_TYPES, SObjectType.Rule__c.fields.SubType__c.getPicklistValues());
        ret.put(ConfigUtil.MONITORING_APP_KEY_USER_TIMEZONE_OFFSET, getUserTimezoneOffset());
        return ret;
    }

    public static Integer getUserTimezoneOffset() {
        Integer userTimezoneOffset = UserInfo.getTimeZone().getOffset(Datetime.now())/(3600*1000);
        return userTimezoneOffset;
    }

    public static Map<String, Object> getActionRules(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String actionId = (String)input.get(ConfigUtil.MONITORING_APP_KEY_ACTION_ID);
        List<NotificationAssigneeData> assignedRulesList = getNotificationAssignee(actionId);
        Map<String, Object> result = new Map<String, Object> {
            ConfigUtil.MONITORING_APP_KEY_ASSIGNED_RULES => assignedRulesList
        };
        return result;
    }

    public static Map<String, List<SelectOptionWrapper>> getActionTypes(String ruleType) {
        Map<String, List<SelectOptionWrapper>> result = new Map<String, List<SelectOptionWrapper>>();
        Map<String, Schema.RecordTypeInfo> rtMapByName = Schema.SObjectType.Action__c.getRecordTypeInfosByName();
        for(String rtName : rtMapByName.keySet()) {
            if(rtName != ruleType) continue;
            Schema.RecordTypeInfo rtInfo = rtMapByName.get(rtName);
            List<SelectOptionWrapper> options = new List<SelectOptionWrapper>();
            for(String actionType : MonitoringUtil.ruleTypeActionsMap.get(ruleType)) {
                options.add(new SelectOptionWrapper(actionType, actionType));
            }
            result.put(rtInfo.getRecordTypeId(), options);
        }
        return result;
    }

    public static Logger_Settings__c setArchivalSetting(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        ConfigUtil.SETTINGS.Archival_Enabled__c = Boolean.valueOf(input.get(ConfigUtil.MONITORING_APP_KEY_ENABLED));
        upsert ConfigUtil.SETTINGS;
        if(ConfigUtil.SETTINGS.Archival_Enabled__c) {
            runArchivalScheduler();
        }
        else {
            stopArchivalScheduler();
        }
        return ConfigUtil.SETTINGS;
    }

    public static Logger_Settings__c setMonitoringSetting(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        ConfigUtil.SETTINGS.Monitoring_Enabled__c = Boolean.valueOf(input.get(ConfigUtil.MONITORING_APP_KEY_ENABLED));
        upsert ConfigUtil.SETTINGS;
        return ConfigUtil.SETTINGS;
    }

    public static Map<String, Object> setBatchErrorTrackingSetting(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        ConfigUtil.SETTINGS.Batch_Error_Tracking_Enabled__c = Boolean.valueOf(input.get(ConfigUtil.MONITORING_APP_KEY_ENABLED));
        upsert ConfigUtil.SETTINGS;
        return getBatchErrorTrackingSetting(null);
    }

    public static Map<String, Object> getBatchErrorTrackingSetting(Object data) {
        Map<String, Object> ret = new Map<String, Object>();
        ret.put(ConfigUtil.BATCH_ERROR_TRACKING_ENABLED, ConfigUtil.SETTINGS.Batch_Error_Tracking_Enabled__c);
        return ret;
    }

    public static Logger_Settings__c setJiraSetting(Object data) {
//      Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
//      ConfigUtil.SETTINGS.Monitoring_Enabled__c = Boolean.valueOf(input.get('enabled'));
//      upsert ConfigUtil.SETTINGS;
        return ConfigUtil.SETTINGS;
    }

    public static Map<String, Object> deleteMonitoringRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String ruleId = (String)input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ID);
        Action__c defaultJiraAction = ConfigUtil.getDefaultJiraAction();
        if(String.isNotBlank(ruleId)) {

            Set<Id> actionIds = new Set<Id>();
            for(RuleAction__c ruleAction : [SELECT Id, Action__c FROM RuleAction__c WHERE Rule__c =:ruleId]) {
                actionIds.add(ruleAction.Action__c);
            }
            for(Action__c action : [SELECT Id FROM Action__c WHERE Id IN (SELECT Action__c FROM RuleAction__c WHERE Action__c IN :actionIds AND Rule__c != :ruleId)]) {
                actionIds.remove(action.Id);
            }
            // don't delete default jira action
            if(defaultJiraAction != null) {
                actionIds.remove(defaultJiraAction.Id);
            }
            if(!actionIds.isEmpty()) {
                Database.DeleteResult[] drActions = Database.delete(new List<Id>(actionIds), false);
            }

            Boolean isJiraRule = isJiraRule(ruleId);
            Database.DeleteResult dr = Database.delete(ruleId, false);
            input.put(ConfigUtil.DELETE_MONITORING_RULE_KEY_SUCCESS, dr.isSuccess());
            input.put(ConfigUtil.DELETE_MONITORING_RULE_KEY_MESSAGE, dr.getErrors());
            if(isJiraRule && dr.isSuccess()) {
                reIndexRules(MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
            }
        }
        else {
            input.put(ConfigUtil.DELETE_MONITORING_RULE_KEY_SUCCESS, false);
            input.put(ConfigUtil.DELETE_MONITORING_RULE_KEY_MESSAGE, ConfigUtil.DELETE_MONITORING_RULE_MESSAGE_BAD_PARAMS);
        }
        return input;
    }

    public static void reIndexRules(String ruleType) {
        List<Rule__c> allRules = getMonitoringRulesData(null, ruleType);
        List<Rule__c> toUpdate = new List<Rule__c>();
        Integer counter = 1;
        if(!allRules.isEmpty()) {
           for(Integer i = 0; i < allRules.size(); i++){
               Integer ruleIndex = (allRules.get(i).Active__c) ? counter++ : null;
               toUpdate.add(new Rule__c(Id = allRules.get(i).Id, Index__c = ruleIndex));
           }
        }
        if(!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Boolean isJiraRule(String ruleId) {
        Boolean result = false;
        if(String.isNotBlank(ruleId)) {
            List<MonitoringRuleData> jiraRules = getJiraRules();
            for(MonitoringRuleData mr : jiraRules) {
                if(mr.id != null && Id.valueOf(mr.id) == Id.valueOf(ruleId)) {
                    result = true;
                    break;
                }
            }
        }
        return result;
    }

    public static Map<String, Object> setRuleIndex(Object data) {
        Map<String, Object> resp = new Map<String, Object>();
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String ruleId = (input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ID) != null) ? (String)input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ID) : null;
        Integer ruleIndex = (input.get(ConfigUtil.MONITORING_APP_KEY_RULE_INDEX) != null) ? (Integer)input.get(ConfigUtil.MONITORING_APP_KEY_RULE_INDEX) : null;
        String ruleType = (input.get(ConfigUtil.MONITORING_APP_KEY_RULE_TYPE) != null) ? (String)input.get(ConfigUtil.MONITORING_APP_KEY_RULE_TYPE) : null;

        if(ruleId != null && ruleIndex != null) {
            List<Rule__c> currentRule = [SELECT Id, Index__c FROM Rule__c WHERE Id = :ruleId LIMIT 1];
            Rule__c toUpdate = new Rule__c(Id = ruleId, Index__c = ruleIndex);
            if(!currentRule.isEmpty() && currentRule.get(0).Index__c != null) {
                List<Rule__c> ruleWithOldIndex = [SELECT Id, Index__c FROM Rule__c WHERE Index__c = :ruleIndex AND Type__c = :ruleType];
                if(!ruleWithOldIndex.isEmpty()) {
                    Rule__c updateRuleOldIndex = new Rule__c(Id = ruleWithOldIndex.get(0).Id, Index__c = currentRule.get(0).Index__c);
                    update updateRuleOldIndex;
                }
            }
            update toUpdate;

        }
        if (ruleType != null && ruleType == MonitoringUtil.RULE_TYPE_NOTIFICATION) {
            Map<String, List<SelectOptionWrapper>> actionTypes = getActionTypes(MonitoringUtil.RULE_TYPE_MONITORING);
            resp = getNotificationSettings(null, actionTypes);
        } else if(ruleType != null && ruleType == MonitoringUtil.RULE_TYPE_JIRA_UPDATE) {
            resp = getJiraDataSettings(null);
        }
        return resp;
    }

    public static Map<String, Object> deleteNotificationRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String ruleActionId = (input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTION_ID) != null) ? (String)input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTION_ID) : null;
        List<RuleAction__c> ruleAction = [SELECT Id, Action__c, Rule__c FROM RuleAction__c WHERE Id = :ruleActionId LIMIT 1];
        List<RuleAction__c> actionsAttachedToOtherRules = new List<RuleAction__c>();

        if(!ruleAction.isEmpty() && String.isNotBlank(ruleAction.get(0).Action__c)) {
            actionsAttachedToOtherRules = [
                SELECT Id
                FROM RuleAction__c
                WHERE Action__c = :ruleAction.get(0).Action__c
                AND Rule__c != :ruleAction.get(0).Rule__c
                LIMIT 1
            ];
        }

        if(actionsAttachedToOtherRules.isEmpty()) {
            Database.DeleteResult dr = Database.delete(ruleAction.get(0).Action__c, false);
            Map<String, Object> actionResult = new Map<String, Object>();
            actionResult.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_SUCCESS, dr.isSuccess());
            actionResult.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_MESSAGE, dr.getErrors());
            input.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_ACTION_RESULT, actionResult);
        }
        Map<String, Object> ruleActionResult = new Map<String, Object>();
        Database.DeleteResult dr = Database.delete(ruleAction.get(0).Id, false);
        ruleActionResult.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_SUCCESS, dr.isSuccess());
        ruleActionResult.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_MESSAGE, dr.getErrors());
        input.put(ConfigUtil.DELETE_MONITORING_RULE_ACTION_KEY_RULE_ACTION_RESULT, ruleActionResult);

        return input;
    }

    public static void setRuleIndex(Rule__c mr, String type) {
        Integer countRules = Database.countQuery('SELECT COUNT() FROM Rule__c WHERE Type__c = :type AND Active__c = true');
        mr.Index__c = mr.Index__c == null ? countRules + 1 : mr.Index__c;
    }

    public static Map<String, Object> setJiraRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_JIRA_RULE_ID)), MonitoringRuleData.class);
        Rule__c mr = mr_data.getMonitoringRuleData(MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
        setRuleIndex(mr, MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
        upsert mr;
        reIndexRules(MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
        upsertFilters(input, mr.Id);
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr.Id, MonitoringUtil.RULE_TYPE_MONITORING);
        }
        return getJiraDataSettings(null);
    }

    public static Map<String, Object> setArchivalRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_RULE_ID)), MonitoringRuleData.class);
        Rule__c mr = mr_data.getMonitoringRuleData(MonitoringUtil.RULE_TYPE_ARCHIVAL);
        upsert mr;
        upsertFilters(input, mr.Id);
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr.Id, MonitoringUtil.RULE_TYPE_ARCHIVAL);
        }
        return getArchivalSettings(null);
    }

    public static Map<String, Object> setMonitoringRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_MONITORING_RULE_ID)), MonitoringRuleData.class);
        Rule__c mr = mr_data.getMonitoringRuleData(MonitoringUtil.RULE_TYPE_MONITORING);
        upsert mr;
        upsertFilters(input, mr.Id);
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr.Id, MonitoringUtil.RULE_TYPE_MONITORING);
        }
        return getMonitoringSettings(null);
    }

    public static Map<String, Object> setNotificationRule(Object data) {
        Map<String, List<SelectOptionWrapper>> actionTypes = getActionTypes(MonitoringUtil.RULE_TYPE_MONITORING);
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_RULE_ID)), MonitoringRuleData.class);
        Rule__c mr = mr_data.getMonitoringRuleData(MonitoringUtil.RULE_TYPE_NOTIFICATION);
        setRuleIndex(mr, MonitoringUtil.RULE_TYPE_NOTIFICATION);
        upsert mr;
        reIndexRules(MonitoringUtil.RULE_TYPE_NOTIFICATION);
        upsertFilters(input, mr.Id);
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr.Id, MonitoringUtil.RULE_TYPE_MONITORING);
        }
        return getNotificationSettings(null, actionTypes);
    }

    public static Map<String, Object> setBroadcastRule(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_BROADCAST_RULE_ID)), MonitoringRuleData.class);
        Rule__c mr = mr_data.getMonitoringRuleData(MonitoringUtil.RULE_TYPE_BROADCAST);
        setRuleIndex(mr, MonitoringUtil.RULE_TYPE_BROADCAST);
        upsert mr;
        reIndexRules(MonitoringUtil.RULE_TYPE_BROADCAST);
        upsertFilters(input, mr.Id);
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr.Id, MonitoringUtil.RULE_TYPE_BROADCAST);
        }
        return getBroadcastSettings(null);
    }

    public static void upsertFilters(Map<String, Object> input, Id ruleId) {
        if (input.get(ConfigUtil.MONITORING_APP_KEY_FILTERS) != null) {
            List<RuleFilterData> rfl = (List<RuleFilterData>)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_FILTERS)), List<RuleFilterData>.class);
            List<RuleFilter__c> rfl_old = getRuleFiltersData(ruleId);
            List<RuleFilter__c> rfl_delete = new List<RuleFilter__c>();
            List<RuleFilter__c> rfl_upsert = new List<RuleFilter__c>();
            Set<Id> set_f = new Set<Id>();
            Integer indexValue = 1;
            Integer indexField = 1;
            for (RuleFilterData f_d: rfl) {
                if (f_d.id != null) set_f.add(f_d.id);
                RuleFilter__c r_u = f_d.getRuleFilterData();
                if (r_u.Rule__c == null) r_u.Rule__c = ruleId;
                if (r_u.Comparison_Type__c == 'Value') {
                    r_u.Index__c = indexValue;
                    indexValue++;
                } else {
                    r_u.Index__c = indexField;
                    indexField++;
                }
                rfl_upsert.add(r_u);
            }
            for (RuleFilter__c f: rfl_old) {
                if (!set_f.contains(f.Id)) rfl_delete.add(f);
            }
            if (!rfl_delete.isEmpty()) delete rfl_delete;
            if (!rfl_upsert.isEmpty()) upsert rfl_upsert;
        }
    }


    public static Map<String, Object> setNotificationRules(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        MonitoringRuleData mr_data;
        String ruleType;
        if(input.get(ConfigUtil.MONITORING_APP_KEY_MONITORING_RULE_ID) != null) {
            mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_MONITORING_RULE_ID)), MonitoringRuleData.class);
            ruleType = MonitoringUtil.RULE_TYPE_MONITORING;
        }
        else if(input.get(ConfigUtil.MONITORING_APP_KEY_JIRA_RULE_ID) != null) {
            mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_JIRA_RULE_ID)), MonitoringRuleData.class);
            ruleType = MonitoringUtil.RULE_TYPE_MONITORING;
        }
        else if(input.get(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_RULE_ID) != null) {
            mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_RULE_ID)), MonitoringRuleData.class);
            ruleType = MonitoringUtil.RULE_TYPE_ARCHIVAL;
        }
        else if(input.get(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_RULE_ID) != null) {
            mr_data = (MonitoringRuleData)JSON.deserialize(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_RULE_ID)), MonitoringRuleData.class);
            ruleType = MonitoringUtil.RULE_TYPE_MONITORING;
        }
        if (input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS) != null && input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS) != null) {
            saveNotificationRules(JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_ACTIONS)), JSON.serialize(input.get(ConfigUtil.MONITORING_APP_KEY_RULE_ACTIONS)), mr_data.id, ruleType);
        }
        if(input.get(ConfigUtil.MONITORING_APP_KEY_JIRA_RULE_ID) != null) {
            return getJiraDataSettings(null);
        }
        else if(input.get(ConfigUtil.MONITORING_APP_KEY_ARCHIVAL_RULE_ID) != null) {
            return getArchivalSettings(null);
        }
        else if(input.get(ConfigUtil.MONITORING_APP_KEY_NOTIFICATION_RULE_ID) != null) {
            return getNotificationSettings(null);
        }
        return getMonitoringSettings(null);
    }

    private static Map<Integer, String> MAP_EXPRESSIONS = new Map<Integer, String>{
            60 => '0 0 * * * ?',
            240 => '0 0 0,4,8,12,16,20 * * ?',
            480 => '0 0 0,8,16 * * ?',
            1440 => '0 0 0 * * ?',
            10080 => '0 0 0 ? * SUN'
    };

    private static String JOB_DETAIL_NAME = 'Pharos Bulk API';

    public static Map<String, Object> getScheduleBulkAPIBatch() {
        Integer cronParameter;
        List<CronTrigger> lstCronTriggers = [SELECT Id, CronJobDetail.Name, CronExpression FROM CronTrigger WHERE CronJobDetail.Name = :JOB_DETAIL_NAME];
        if (!lstCronTriggers.isEmpty()) {
            for (Integer key : MAP_EXPRESSIONS.keySet()) {
                if (lstCronTriggers[0].CronExpression == MAP_EXPRESSIONS.get(key)) {
                    cronParameter = key;
                }
            }
        }
        return new Map<String, Object>{'cronParameter' => cronParameter};
    }

    public static Map<String, Object> abortScheduleBulkAPIBatch() {
        List<CronTrigger> lstCronTriggers = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name = :JOB_DETAIL_NAME];
        if (!lstCronTriggers.isEmpty()) {
            System.abortJob(lstCronTriggers[0].Id);
        }
        return new Map<String, Object>{'jobId' => null};
    }

    public static Map<String, Object> scheduleBulkAPIBatch(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        String jobId;
        if (Integer.valueOf(input.get('cronParameter')) == 0) {
            BulkAPIJobBatchScheduler bulkAPIJobBatchScheduler = new BulkAPIJobBatchScheduler();
            bulkAPIJobBatchScheduler.execute(null);
        } else {
            String sch = MAP_EXPRESSIONS.get(Integer.valueOf(input.get('cronParameter')));
            if (String.isNotBlank(sch)) {
                abortScheduleBulkAPIBatch();
                jobId = System.schedule(JOB_DETAIL_NAME, sch, new BulkAPIJobBatchScheduler());
            }
        }
        return new Map<String, Object>{'jobId' => jobId};
    }

    public static void saveNotificationRules(String actionsjson, String ruleActionsjson, String ruleId, String ruleType) {
        List<NotificationRuleData> actions = (List<NotificationRuleData>)JSON.deserialize(actionsjson, List<NotificationRuleData>.class);
        List<NotificationAssigneeData> ruleActions = (List<NotificationAssigneeData>)JSON.deserialize(ruleActionsjson, List<NotificationAssigneeData>.class);
        List<Action__c> actionsToInsert = new List<Action__c>();
        List<Action__c> actionsToUpdate = new List<Action__c>();
        List<RuleAction__c> ruleActionsToInsert = new List<RuleAction__c>();
        List<RuleAction__c> ruleActionsToUpdate = new List<RuleAction__c>();

        List<Action__c> defaultJiraAction = [
            SELECT Id
            FROM Action__c
            WHERE (Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION OR Action_Type__c = :MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                AND Subtype__c = :MonitoringUtil.ACTION_SUBTYPE_DEFAULT
            LIMIT 1
        ];

        List<RuleAction__c> existRuleActions = [
            SELECT Id, Rule__c, Action__c, Action__r.Type__c,Action__r.Action_Type__c, Action__r.Subtype__c
            FROM RuleAction__c
            WHERE Rule__c = :ruleId AND Action__c != NULL
        ];
        Map<Id, RuleAction__c> mapExistRuleActions = new Map<Id, RuleAction__c>(existRuleActions);

        List<Action__c> newActions = new List<Action__c>();
        Integer ruleActionIndex = 0;
        for (NotificationRuleData action : actions) {
            NotificationAssigneeData ruleActionWrapper = ruleActions.get(ruleActionIndex++);
            Action__c actionRecord = action.getNotificationRuleData(ruleType);
            if (((actionRecord.Id == null && ruleActionWrapper.id == null) || (actionRecord.Id == null && ruleActionWrapper.rulenotificationid == null))
                    && actionRecord.Subtype__c != MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                newActions.add(actionRecord);
            }
        }
        if(!newActions.isEmpty()) {
            insert newActions;
        }

        ruleActionIndex = 0;
        Integer newActionIndex = 0;
        for (NotificationRuleData action : actions) {
            NotificationAssigneeData ruleActionWrapper = ruleActions.get(ruleActionIndex++);
            Action__c actionRecord = action.getNotificationRuleData(ruleType);

            // new ruleAction
            if(ruleActionWrapper.id == null) {

                // add new Action to rule
                if(actionRecord.Id == null) {
                    // if new Action__c jira default
                    if((actionRecord.Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
                            || actionRecord.Action_Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                            && actionRecord.Subtype__c == MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                        // if default jira action already exist
                        if(!defaultJiraAction.isEmpty()) {
                            RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                            newRuleAction.Action__c = defaultJiraAction.get(0).Id;
                            newRuleAction.Rule__c = ruleId;
                            ruleActionsToInsert.add(newRuleAction);
                        }
                    }
                    // any non jira-default actions
                    else {
                        RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                        newRuleAction.Action__c = newActions.get(newActionIndex++).Id;
                        newRuleAction.Rule__c = ruleId;
                        ruleActionsToInsert.add(newRuleAction);
                    }
                }
                // add exist Action__c to rule
                else if(actionRecord.Id == ruleActionWrapper.rulenotificationid) {

                    // if edited Action__c jira default
                    if((actionRecord.Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
                            || actionRecord.Action_Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                            && actionRecord.Subtype__c == MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                        // if default jira action already exist
                        if(!defaultJiraAction.isEmpty()) {
                            RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                            newRuleAction.Action__c = defaultJiraAction.get(0).Id;
                            newRuleAction.Rule__c = ruleId;
                            ruleActionsToInsert.add(newRuleAction);
                        }
                    }
                    // any non jira-default actions
                    else {
                        RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                        newRuleAction.Rule__c = ruleId;
                        ruleActionsToInsert.add(newRuleAction);
                        actionsToUpdate.add(actionRecord);
                    }
                }
            }
            // update ruleAction
            else {
                RuleAction__c existRuleAction = mapExistRuleActions.get(ruleActionWrapper.id);

                // update exist Action__c on exist RuleAction__c
                if(actionRecord.Id != null && actionRecord.Id == ruleActionWrapper.rulenotificationid) {

                    // update from exist not-default to default
                    if((actionRecord.Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
                            || actionRecord.Action_Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                            && actionRecord.Subtype__c == MonitoringUtil.ACTION_SUBTYPE_DEFAULT
                            && existRuleAction.Action__r.Subtype__c != MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                        RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                        newRuleAction.Action__c = defaultJiraAction.get(0).Id;
                        ruleActionsToUpdate.add(newRuleAction);

                    }
                    // update from exist defult to not-default
                    else if((actionRecord.Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
                            || actionRecord.Action_Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                            && actionRecord.Subtype__c != MonitoringUtil.ACTION_SUBTYPE_DEFAULT
                            && existRuleAction.Action__c != null
                            && existRuleAction.Action__r.Subtype__c == MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                        actionRecord.Id = null;
                        insert actionRecord;
                        RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                        newRuleAction.Action__c = actionRecord.Id;
                        ruleActionsToUpdate.add(newRuleAction);
                    }
                    // any non jira-default actions
                    else if (actionRecord.Subtype__c != MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {
                        actionsToUpdate.add(actionRecord);
                    }
                }
                else if(actionRecord.Id == null && ruleActionWrapper.rulenotificationid == null) {
                    // if edited Action__c jira default
                    if((actionRecord.Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION
                            || actionRecord.Action_Type__c == MonitoringUtil.ACTION_TYPE_JIRA_NOTIFICATION)
                            && actionRecord.Subtype__c == MonitoringUtil.ACTION_SUBTYPE_DEFAULT) {

                        // if default jira action already exist
                        if(!defaultJiraAction.isEmpty()) {
                            RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                            newRuleAction.Action__c = defaultJiraAction.get(0).Id;
                            ruleActionsToUpdate.add(newRuleAction);
                        }
                    }
                    // any non jira-default actions
                    else {
                        RuleAction__c newRuleAction = ruleActionWrapper.getNotificationAssigneeData();
                        newRuleAction.Action__c = newActions.get(newActionIndex++).Id;
                        ruleActionsToUpdate.add(newRuleAction);
                    }
                }
            }
        }

        if(!actionsToInsert.isEmpty()) {
            insert actionsToInsert;
        }

        if(!actionsToUpdate.isEmpty()) {
            update actionsToUpdate;
        }

        if(!ruleActionsToInsert.isEmpty()) {
            insert ruleActionsToInsert;
        }

        if(!ruleActionsToUpdate.isEmpty()) {
            update ruleActionsToUpdate;
        }
    }

    public static List<MonitoringRuleData> getMonitoringRules() {
        return getRules(MonitoringUtil.RULE_TYPE_MONITORING);
    }

    public static List<MonitoringRuleData> getArchivalRules() {
        return getRules(MonitoringUtil.RULE_TYPE_ARCHIVAL);
    }

    public static List<MonitoringRuleData> getJiraRules() {
        return getRules(MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
    }

    public static List<MonitoringRuleData> getNotificationRules() {
        return getRules(MonitoringUtil.RULE_TYPE_NOTIFICATION);
    }

    public static List<MonitoringRuleData> getBroadcastRules() {
        return getRules(MonitoringUtil.RULE_TYPE_BROADCAST);
    }

    public static List<MonitoringRuleData> getRules(String ruleType) {
        List<MonitoringRuleData> data = new List<MonitoringRuleData>();
        List<Rule__c> mrl = getMonitoringRulesData(null, ruleType);
        if (mrl != null && !mrl.isEmpty()) {
            for (Rule__c mr: mrl) {
                data.add(new MonitoringRuleData(mr));
            }
        }
        return data;
    }

    public static List<RuleFilterData> getMonitoringRuleFilters() {
        List<RuleFilterData> data = new List<RuleFilterData>();
        List<RuleFilter__c> rfl = getRuleFiltersData(null);
        if (rfl != null && !rfl.isEmpty()) {
            for (RuleFilter__c rf: rfl) {
                data.add(new RuleFilterData(rf));
            }
        }
        return data;
    }

    public static List<NotificationRuleData> getMonitoringActions() {
        return getActions(MonitoringUtil.RULE_TYPE_MONITORING);
    }

    public static List<NotificationRuleData> getArchivalActions() {
        return getActions(MonitoringUtil.RULE_TYPE_ARCHIVAL);
    }

    public static List<NotificationRuleData> getJiraActions() {
        return getActions(MonitoringUtil.RULE_TYPE_JIRA_UPDATE);
    }

    public static List<NotificationRuleData> getNotificationActions() {
        return getActions(MonitoringUtil.RULE_TYPE_NOTIFICATION, MonitoringUtil.ACTION_SUB_TYPE_NOTIFICATION);
    }

    public static List<NotificationRuleData> getBroadcastActions() {
        return getActions(MonitoringUtil.RULE_TYPE_BROADCAST);
    }

    public static List<NotificationRuleData> getActions(String ruleType) {
        return getActions(ruleType, null);
    }

    public static List<NotificationRuleData> getActions(String ruleType, String subType) {
        List<NotificationRuleData> data = new List<NotificationRuleData>();
        List<Action__c> nrl = getNotificationRulesData(ruleType, subType);
        if (nrl != null && !nrl.isEmpty()) {
            for (Action__c nr: nrl) {
                data.add(new NotificationRuleData(nr));
            }
        }
        return data;
    }

    public static List<NotificationAssigneeData> getNotificationAssignee() {
        List<NotificationAssigneeData> data = new List<NotificationAssigneeData>();
        List<RuleAction__c> nal = [
            SELECT Id, Rule__c, Action__c, Rule__r.Name__c, Rule__r.Description__c, Action__r.Name, Action__r.Type__c, Action__r.Action_Type__c, Action__r.Subject__c
            FROM RuleAction__c
            WHERE Rule__c != null AND Action__c != null
        ];
        if (nal != null && !nal.isEmpty()) {
            for (RuleAction__c na: nal) {
                data.add(new NotificationAssigneeData(na));
            }
        }
        return data;
    }

    public static List<NotificationAssigneeData> getNotificationAssignee(String actionId) {
        List<NotificationAssigneeData> data = new List<NotificationAssigneeData>();
        List<RuleAction__c> nal = [
            SELECT Id, Rule__c, Action__c, Rule__r.Name__c, Rule__r.Description__c, Action__r.Name, Action__r.Type__c,Action__r.Action_Type__c, Action__r.Subject__c
            FROM RuleAction__c
            WHERE Rule__c != null AND Action__c = : actionId
        ];
        if (nal != null && !nal.isEmpty()) {
            for (RuleAction__c na: nal) {
                data.add(new NotificationAssigneeData(na));
            }
        }
        return data;
    }

    public final static List<String> RULE_FIELDS = new List<String>{
        'Id', 'Name', 'Active__c', 'Description__c', 'Related_Id__c', 'CreatedBy.Name', 'Name__c', 'ComparisonOperator__c',
        'AggregateType__c', 'FilterLogic__c', 'Index__c', 'Threshold__c', 'EventTimeInterval__c', 'AggregateInterval__c',
        'Type__c', 'Subtype__c', 'Index__c'
    };

    public final static List<String> RULE_FILTER_FIELDS = new List<String>{
        'Id', 'Name', 'ComparisonOperator__c', 'Comparison_Type__c', 'FieldName__c', 'Index__c', 'Rule__c', 'Value__c', 'Field_Type__c'
    };

    public final static List<String> ACTION_FIELDS = new List<String>{
        'Id', 'Name', 'Body__c', 'Description__c', 'EmailBody__c', 'EmailCC__c', 'EmailTemplateId__c', 'EmailTo__c',
        'JIRAAssignee__c','JIRAAssignee_Id__c', 'JIRAComponents__c', 'JIRAEpic__c', 'JIRAIssueType__c', 'JIRALabels__c', 'JIRAPriority__c', 'JIRAProject__c',
        'SlackChannels__c', 'Subject__c', 'Type__c', 'Action_Type__c', 'Subtype__c', 'PagerDuty_Type__c', 'Contact__c', 'Contact__r.Name', 'CreatedBy.Name', 'RecordTypeId',
        'Team_Id__c', 'Channel_Id__c'
    };

    public static List<Rule__c> getMonitoringRulesData(Id ruleId, String ruleType) {
        String query = new QBuilder(Rule__c.SObjectType)
                .selectFields(new Set<String>(RULE_FIELDS))
                    .addSubquery(new QBuilder('RuleActions__r')
                        .selectFields(new Set<String>{'Id', 'Action__r.Type__c', 'Action__r.Action_Type__c'})
                        .add(QBuilder.orderBy('CreatedDate').descending()))
                .add(ruleId != null ? QBuilder.condition('Rule__c').equalsTo(ruleId) : null)
                .add(QBuilder.condition('Type__c').equalsTo(ruleType))
                .add(QBuilder.orderBy('Index__c').ascending().nullsLast())
                .build();
        return Database.query(query);
    }

    public static List<RuleFilter__c> getRuleFiltersData(Id ruleId) {
        String query = new QBuilder(RuleFilter__c.SObjectType)
                .selectFields(new Set<String>(RULE_FILTER_FIELDS))
                .add(ruleId != null ? QBuilder.condition('Rule__c').equalsTo(ruleId) : null)
                .add(QBuilder.orderBy('Index__c').descending())
                .build();
        return Database.query(query);
    }

    public static List<Action__c> getNotificationRulesData(String ruleType) {
        return getNotificationRulesData(ruleType, null);
    }

    public static List<Action__c> getNotificationRulesData(String ruleType, String subType) {
        List<String> actionTypes = MonitoringUtil.ruleTypeActionsMap.get(ruleType);
        List<Action__c> actions = new List<Action__c>();
        if(String.isNotBlank(subType)) {
            actions = [
                SELECT Id, Name, Body__c, Description__c, EmailBody__c, EmailCC__c,
                    EmailTemplateId__c, EmailTo__c, JIRAAssignee__c, JIRAAssignee_Id__c,
                    JIRAComponents__c, JIRAEpic__c, JIRAIssueType__c, JIRALabels__c, JIRAPriority__c,
                    JIRAProject__c, SlackChannels__c, Subject__c, Type__c, Action_Type__c, Subtype__c,
                    PagerDuty_Type__c, Contact__c, Contact__r.Name, CreatedBy.Name, RecordTypeId,
                    Team_Id__c, Channel_Id__c
                FROM Action__c
                WHERE (Type__c IN :actionTypes OR Action_Type__c IN :actionTypes)
                    AND SubType__c = :subType
                ORDER BY CreatedDate DESC
            ];
        }
        else {
            actions = [
                SELECT Id, Name, Body__c, Description__c, EmailBody__c, EmailCC__c,
                    EmailTemplateId__c, EmailTo__c, JIRAAssignee__c, JIRAAssignee_Id__c,
                    JIRAComponents__c, JIRAEpic__c, JIRAIssueType__c, JIRALabels__c, JIRAPriority__c,
                    JIRAProject__c, SlackChannels__c, Subject__c, Type__c, Action_Type__c, Subtype__c,
                    PagerDuty_Type__c, Contact__c, Contact__r.Name, CreatedBy.Name, RecordTypeId,
                    Team_Id__c, Channel_Id__c
                FROM Action__c
                WHERE (Type__c IN :actionTypes OR Action_Type__c IN :actionTypes)
                AND SubType__c != :MonitoringUtil.ACTION_SUB_TYPE_NOTIFICATION
                ORDER BY CreatedDate DESC
            ];
        }
        return actions;
    }

    // data for logs charts
    public static String getOccurrenceLogs(Object data) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(data));
        Log__c currentLog = (Log__c)JSON.deserialize(JSON.serialize(input.get('currentLog')), Log__c.class);
        String showDays = (input.get('showDays') != null) ? (String)input.get('showDays') : null;
        Date endDate;
        Date startDate;

        currentLog = [
            SELECT Id, Name, Hash__c, Hash_1__c, Hash_2__c, Hash_3__c, Created_At__c, Summary__c, Organization_Id__c
            FROM Log__c
            WHERE Id = :currentLog.Id
        ];

        if (showDays == '7' || showDays == '30' || showDays == '60' || showDays == '180') {
            endDate = Date.today();
            startDate = endDate.addDays(-1 * Integer.valueOf(showDays));
        } else {
            endDate = Date.today();
            startDate = endDate.addDays(-30);
        }

        List<Log__c> logsWithHash1 = [
            SELECT Id, Created_At__c
            FROM Log__c
            WHERE (Hash_1__c = :currentLog.Hash_1__c AND
                      Organization_Id__c = :currentLog.Organization_Id__c AND
                  Hash_1__c != null AND
                  DAY_ONLY(Created_At__c) >= :startDate AND
                  DAY_ONLY(Created_At__c) <= :endDate) OR
                  Id = :currentLog.Id
            ORDER BY Created_At__c];
        List<Log__c> logsWithHash2 = [
            SELECT Id, Created_At__c
            FROM Log__c
            WHERE Hash_2__c = :currentLog.Hash_2__c AND
                  Organization_Id__c = :currentLog.Organization_Id__c AND
                  Hash_2__c != null AND
                  DAY_ONLY(Created_At__c) >= :startDate AND
                  DAY_ONLY(Created_At__c) <= :endDate AND
                  Id != :currentLog.Id
            ORDER BY Created_At__c];
        List<Log__c> logsWithHash3 = [
            SELECT Id, Created_At__c
            FROM Log__c
            WHERE Hash_3__c = :currentLog.Hash_3__c AND
                  Organization_Id__c = :currentLog.Organization_Id__c AND
                  Hash_3__c != null AND
                  DAY_ONLY(Created_At__c) >= :startDate AND
                  DAY_ONLY(Created_At__c) <= :endDate AND
                  Id != :currentLog.Id
            ORDER BY Created_At__c];

        Map<String, Object> dataMap = new Map<String, Object>();
        dataMap.put('hash1', logsWithHash1);
        dataMap.put('hash2', logsWithHash2);
        dataMap.put('hash3', logsWithHash3);
        String result = JSON.serialize(dataMap);
        return result;
    }

    public static String getInstalledVersion() {
        List<Publisher> pharosPublisher = [
            SELECT
                Id,
                Name,
                MajorVersion,
                MinorVersion
            FROM Publisher
            WHERE Name = :ConfigUtil.PHAROS_PACKAGE_PUBLISHER
            LIMIT 1
        ];

        return !pharosPublisher.isEmpty() ? pharosPublisher[0].MajorVersion + '.' + pharosPublisher[0].MinorVersion : 'Unmanaged';
    }

    public static SubscriptionInfo getSubscriptionInfo() {
        SubscriptionInfo info = new SubscriptionInfo();
        info.edition = PermissionsUtil.ChargifyProductEdition;

        List<PackageLicense> currentLicense = [
            SELECT Id, Status, IsProvisioned, AllowedLicenses, UsedLicenses, ExpirationDate, CreatedDate, NamespacePrefix
            FROM PackageLicense
            WHERE NamespacePrefix = :ConfigUtil.NS
            LIMIT 1
        ];
        if(!currentLicense.isEmpty()) {
            info.status = currentLicense.get(0).Status;
            info.expired = currentLicense.get(0).ExpirationDate;
        }

        return info;
    }

    public class SubscriptionInfo {
        public String edition;
        public String status;
        public DateTime expired;

        public SubscriptionInfo(){}
    }

    public class NotificationAssigneeData {
        public String id;
        public String monitoringruleid;
        public String rulenotificationid;
        public String ruleName;
        public String ruleDescription;
        public String actionName;
        public String actionType;
        public String actionSubject;
        public NotificationAssigneeData(RuleAction__c na) {
            id = na.id;
            monitoringruleid = na.Rule__c;
            rulenotificationid = na.Action__c;

            ruleName = na.Rule__r.Name__c;
            ruleDescription = na.Rule__r.Description__c;
            actionName = na.Action__r.Name;
            actionType = na.Action__r.Action_Type__c != null ? na.Action__r.Action_Type__c : na.Action__r.Type__c;
            actionSubject = na.Action__r.Subject__c;
        }
        public RuleAction__c getNotificationAssigneeData() {
            return new RuleAction__c(
                Id = id,
                Rule__c = monitoringruleid,
                Action__c = rulenotificationid
            );
        }
    }

    public class NotificationRuleData {
        public String id;
        public String name;
        public String body;
        public String description;
        public String emailbody;
        public String emailcc;
        public String emailtemplateid;
        public String emailto;
        public String jiraassignee;
        public String jiraassigneeid;
        public String jiracomponents;
        public String jiraepic;
        public String jiraissuetype;
        public String jiralabels;
        public String jirapriority;
        public String jiraproject;
        public String slackchannels;
        public String subject;
        public String type;
        public String subtype;
        public String pagerDutytype;
        public String contactid;
        public String contactname;
        public String createby;
        public String recordtypeid;
        public String teamid;
        public String channelid;
        public NotificationRuleData(Action__c rn) {
            id = rn.Id;
            name = rn.Name;
            body = rn.Body__c;
            description = rn.Description__c;
            emailbody = rn.EmailBody__c;
            emailcc = rn.EmailCC__c;
            emailtemplateid = rn.EmailTemplateId__c;
            emailto = rn.EmailTo__c;
            jiraassignee = rn.JIRAAssignee__c;
            jiraassigneeid = rn.JIRAAssignee_Id__c;
            jiracomponents = rn.JIRAComponents__c;
            jiraepic = rn.JIRAEpic__c;
            jiraissuetype = rn.JIRAIssueType__c;
            jiralabels = rn.JIRALabels__c;
            jirapriority = rn.JIRAPriority__c;
            jiraproject = rn.JIRAProject__c;
            slackchannels = rn.SlackChannels__c;
            subject = rn.Subject__c;
            type = rn.Action_Type__c != null ? rn.Action_Type__c : rn.Type__c;
            subtype = rn.Subtype__c;
            pagerDutytype = rn.PagerDuty_Type__c;
            contactid = rn.Contact__c;
            contactname = rn.Contact__c != null ? rn.Contact__r.Name : null;
            createby = rn.CreatedBy.Name;
            recordtypeid = rn.RecordTypeId;
            teamid = rn.Team_Id__c;
            channelid = rn.Channel_Id__c;
        }

        public Action__c getNotificationRuleData(String ruleType) {
            Schema.RecordTypeInfo ruleRT = Schema.SObjectType.Action__c.getRecordTypeInfosByName().get(ruleType);

            return new Action__c(
                Id = id, Body__c = body, Description__c = description, EmailBody__c = emailbody, EmailCC__c = emailcc,
                EmailTemplateId__c = emailtemplateid, EmailTo__c = emailto, JIRAAssignee__c = jiraassignee,JIRAAssignee_Id__c = jiraassigneeid,
                JIRAComponents__c = jiracomponents, JIRAEpic__c = jiraepic, JIRAIssueType__c = jiraissuetype,
                JIRALabels__c = jiralabels, JIRAPriority__c = jirapriority, JIRAProject__c = jiraproject,
                SlackChannels__c = slackchannels, Subject__c = subject, Action_Type__c = type, PagerDuty_Type__c = pagerDutytype,
                Contact__c = (contactid != null ? contactid : null), RecordTypeId = ruleRT.getRecordTypeId(),
                Subtype__c = subtype, Team_Id__c = teamid, Channel_Id__c = channelid
            );
        }
    }

    public class RuleFilterData {
        public String id;
        public String comparisonoperator;
        public String comparisontype;
        public String fieldname;
        public Decimal index;
        public String monitoringruleid;
        public String value;
        public String fieldType;
        public RuleFilterData(RuleFilter__c rf) {
            id = rf.Id;
            comparisonoperator = rf.ComparisonOperator__c;
            comparisontype = rf.Comparison_Type__c;
            fieldname = rf.FieldName__c;
            index = rf.Index__c;
            monitoringruleid = rf.Rule__c;
            value = rf.Value__c;
            fieldType = rf.Field_Type__c;
        }
        public RuleFilter__c getRuleFilterData() {
            return new RuleFilter__c(
                Id = id, ComparisonOperator__c = comparisonoperator, Comparison_Type__c = comparisontype,
                FieldName__c = fieldname, Index__c = index, Rule__c = monitoringruleid, Value__c = value, Field_Type__c = fieldType
            );
        }
    }

    public class MonitoringRuleData {
        public String id;
        public String name;
        public String description;
        public String relatedId;
        public String createby;
        public Boolean ruleEnabled;
        public String ruleType;
        public String ruleSubType;
        public String comparisonoperator;
        public String aggregatetype;
        public String filterlogic;
        public Decimal threshold;
        public Decimal eventtimeinterval;
        public Decimal aggregateinterval;
        public String notifications;
        public Decimal index;
        public MonitoringRuleData(Rule__c mr) {
            id = mr.Id;
            name = mr.Name__c;
            ruleEnabled = mr.Active__c;
            description = mr.Description__c;
            relatedId = mr.Related_Id__c;
            createby = mr.CreatedBy.Name;
            ruleType = mr.Type__c;
            ruleSubType = mr.Subtype__c;
            comparisonoperator = mr.ComparisonOperator__c;
            aggregatetype = mr.AggregateType__c;
            filterlogic = mr.FilterLogic__c;
            threshold = mr.Threshold__c;
            eventtimeinterval = mr.EventTimeInterval__c;
            aggregateinterval = mr.AggregateInterval__c;
            index = mr.Index__c;
            List<String> notificationsList = new List<String>();
            for (RuleAction__c n : mr.RuleActions__r) {
                if(String.isNotBlank(n.Action__r.Type__c)) {
                    notificationsList.add(n.Action__r.Type__c);
                }
                if(String.isNotBlank(n.Action__r.Action_Type__c)) {
                    notificationsList.add(n.Action__r.Action_Type__c);
                }
            }
            notifications = String.join(notificationsList, ', ');
        }
        public Rule__c getMonitoringRuleData(String ruleType) {
            return new Rule__c(
                Id = id, Name__c = name, Active__c = ruleEnabled,
                Description__c = description, Related_Id__c = relatedId,
                Type__c = ruleType, Subtype__c = ruleSubType, Index__c = index,
                ComparisonOperator__c = comparisonoperator, AggregateType__c = aggregatetype,
                FilterLogic__c = filterlogic, Threshold__c = threshold,
                EventTimeInterval__c = eventtimeinterval, AggregateInterval__c = aggregateinterval
            );
        }
    }

    public class SensitiveDataMaskWrapper {
        public String id;
        public String name;
        public String regex;
        public String description;
        public SensitiveDataMaskWrapper(SensitiveDataMask__c mask) {
            id = mask.Name;
            name = mask.Name;
            regex = mask.Regex__c;
            description = mask.Description__c;
        }
    }

    public class LogAccessData {
        public PermissionSet readPermissionSet;
        public PermissionSet readWritePermissionSet;
        public List<PermissionSetAssignment> assignments;
    }

    public class SlackSettings {
        public Boolean slackEnabled;
        public Boolean slackNewLogsEnabled;
        public String slackToken;
        public String slackChannelId;
        public String template;
        public String oAuthEndpoint;

        public SlackSettings() {}

        public SlackSettings(Slack_Settings__c slackSettings, String template) {
            this.slackEnabled = slackSettings.Slack_Enabled__c;
            this.slackNewLogsEnabled = slackSettings.Slack_New_Logs_Enabled__c;
            this.slackToken = slackSettings.Slack_API_Token__c;
            this.slackChannelId = slackSettings.Slack_Channel_ID__c;
            this.template = template;
        }
    }

    public class PagerDutySettings {
        public Boolean enabled;
        public String token;
        public String serviceId;
        public String serviceIntegrationKey;
        public String userEmail;

        public PagerDutySettings() {}

        public PagerDutySettings(Pager_Duty_Settings__c pagerDutySettings) {
            this.enabled = pagerDutySettings.PagerDuty_Enabled__c;
            this.token = pagerDutySettings.PagerDuty_API_Token__c;
            this.serviceId = pagerDutySettings.PagerDuty_Service_ID__c;
            this.serviceIntegrationKey = pagerDutySettings.PagerDuty_Service_Integration_Key__c;
            this.userEmail = pagerDutySettings.PagerDuty_User_Email__c;
        }
    }

    public class TeamsSettings {
        public String apiToken;
        public Boolean isConnectionValid;
        public Boolean enabled;
        public String oAuthEndpoint;

        public TeamsSettings(Graph_API_Settings__c settings) {
            this.apiToken = GraphAPIService.getDecryptedGraphTokenFromCache();
            this.enabled = settings.Enabled__c;
        }
    }

    public class GitHubSettings {
        public String apiToken;
        public String oauthToken;
        public String reponame;
        public String branchName;
        public Boolean isConnectionValid;
        public Boolean enabled;
        public String oAuthEndpoint;

        public GitHubSettings(Git_API_Settings__c settings) {
            this.apiToken = settings.Token__c;
            this.oauthToken = settings.oAuth_Token__c;
            this.enabled = settings.Enabled__c;
            this.reponame = settings.Reponame__c;
            this.branchName = settings.Branch_Name__c;
        }
    }

    public class ChangeTrackingSettings {
        public Boolean gitChangeTracking;

        public ChangeTrackingSettings(Change_Tracking__c settings) {
            this.gitChangeTracking = settings.Git_Change_Tracking__c;
        }
    }

    public class JiraSettings {
        public String baseUrl;
        public String apiToken;
        public String username;
        public String jiraproject;
        public String jiraissuetype;
        public Boolean isConnectionValid;
        public Boolean autoJiraTask;
        public Boolean autoJiraTaskLabelsFromHashes;
        public Boolean autoRelateTicketsWithSimilarErrors;
        public Boolean createUniqueTicketsByOrg;
        public Object projectsData;
        public Object jiraPriorities;
        public String jiraassignee;
        public String jiraassigneeid;
        public String jiracomponents;
        public String jiraepic;
        public String jiralabels;
        public String priority;
        public String jirapriority;
        public String subject;
        public String body;
        public String oAuthEndpoint;

        public JiraSettings() {}

        public JiraSettings(Jira_Settings__c jiraSettings, Action__c defaultJiraAction) {
            this.baseUrl = jiraSettings.Jira_Base_Url__c;
            this.apiToken = ConfigUtil.JIRA_OAUTH_TOKEN;
            this.username = jiraSettings.Jira_Username__c;
            this.autoJiraTaskLabelsFromHashes = jiraSettings.Auto_Generate_Similarity_Labels__c;
            this.autoRelateTicketsWithSimilarErrors = jiraSettings.Auto_Relate_Tickets_With_Similar_Errors__c;
            this.createUniqueTicketsByOrg = jiraSettings.Create_Unique_Tickets_by_Org__c;

            this.jiraproject = defaultJiraAction.JIRAProject__c;
            this.jiraissuetype = defaultJiraAction.JIRAIssueType__c;
            this.jiraassignee = defaultJiraAction.JIRAAssignee__c;
            this.jiraassigneeid = defaultJiraAction.JIRAAssignee_Id__c;
            this.jiracomponents = defaultJiraAction.JIRAComponents__c;
            this.jiraepic = defaultJiraAction.JIRAEpic__c;
            this.jiralabels = defaultJiraAction.JIRALabels__c;
            this.jirapriority = defaultJiraAction.JIRAPriority__c;
            this.subject = defaultJiraAction.Subject__c;
            this.body = defaultJiraAction.Body__c;
        }
    }

    public class SplunkSettings {
        public Boolean enabled = false;
        public String url;
        public String token;
        public String ecToken;
        public List<Map<String, String>> logFields;
        public List<String> config;

        public SplunkSettings() {}

        public SplunkSettings(Splunk_Settings__c splunkSettings) {
            this.enabled = splunkSettings.Splunk_Enabled__c;
            this.url = splunkSettings.Splunk_Url__c;
            this.token = splunkSettings.Splunk_Token__c;
            this.ecToken = splunkSettings.Splunk_Event_Collector_Token__c;
            this.logFields = new List<Map<String, String>>();
        }
    }

    public class RemoteSiteSettingsWrapper {
        public String Id;
        public Boolean IsActive;
        public String SiteName;
        public String EndpointUrl;
    }

    public class SObjectsCreateResponse {
        public String id;
        public Boolean success;
    }


    public class AdminServiceException extends Exception {}

    public static final String PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME = 'PharosOrderEventTriggerConfig';
    public static final Integer PLATFORM_EVENT_SUBSCRIBER_CONFIG_BATCH_SIZE = 200;

    public static PlatformEventSubscriberConfigWrapper getPlatformEventSubscriberConfig() {
        return getPlatformEventSubscriberConfig(true);
    }

    public static PlatformEventSubscriberConfigWrapper getPlatformEventSubscriberConfig(Boolean filterByTriggerId) {
        PlatformEventSubscriberConfigWrapper result = new PlatformEventSubscriberConfigWrapper();
        String triggerId = platformEventSubscriberTriggerId;
        if(String.isNotBlank(triggerId)) {
            String query = new QBuilder('PlatformEventSubscriberConfig')
                .selectFields(new Set<String>{'Id','UserId', 'PlatformEventConsumerId', 'DeveloperName', 'MasterLabel','BatchSize'})
                .add(QBuilder.condition('DeveloperName').equalsTo(PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME))
                .add(filterByTriggerId ? QBuilder.condition('PlatformEventConsumerId').equalsTo(triggerId) : null)
                .addLimit(1)
                .build();
            List<Object> records = HttpUtils.runToolingQuery(System.Url.getOrgDomainUrl().toExternalForm(), UserInfo.getSessionId(), query, ConfigUtil.TOOLING_QUERY_API_51_ENDPOINT);
            if(records != null) {
                for (Object sobjectItem : records) {
                    PlatformEventSubscriberConfigWrapper w1 = (PlatformEventSubscriberConfigWrapper)JSON.deserialize(JSON.serialize(sobjectItem), PlatformEventSubscriberConfigWrapper.class);
                    result = w1;
                    break;
                }}
        }
        return result;
    }

    public static String platformEventSubscriberTriggerId {
        get {
            if(platformEventSubscriberTriggerId == null) {
                platformEventSubscriberTriggerId = [SELECT Id FROM ApexTrigger WHERE Name =: ConfigUtil.PLATFORM_EVENT_SUBSCRIBER_CONFIG_TRIGGER_NAME LIMIT 1].Id;
            }
            return platformEventSubscriberTriggerId;
        }
        private set;
    }

    public static PlatformEventSubscriberConfigWrapper setPlatformEventSubscriberConfig(String userId) {
        PlatformEventSubscriberConfigWrapper result;
        result = getPlatformEventSubscriberConfig(false);
        String triggerId = platformEventSubscriberTriggerId;
        if(String.isNotBlank(triggerId)) {
            if(result == null || String.isBlank(result.Id)) {
                result = new PlatformEventSubscriberConfigWrapper();
                result.DeveloperName = PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME;
                result.MasterLabel = PLATFORM_EVENT_SUBSCRIBER_CONFIG_NAME;
                result.PlatformEventConsumerId = triggerId;
                result.UserId = userId;
                result.BatchSize = PLATFORM_EVENT_SUBSCRIBER_CONFIG_BATCH_SIZE;
                HttpUtils.runToolingPost(System.Url.getOrgDomainUrl().toExternalForm(), UserInfo.getSessionId(), JSON.serialize(result), ConfigUtil.TOOLING_API_UPDATE_PLATFORM_EVENT_SUBSCRIBER_CONFIG);
            }
            else if(result.UserId != userId || result.PlatformEventConsumerId != triggerId) {
                String recordId = result.Id;
                result.UserId = userId;
                result.PlatformEventConsumerId = triggerId;
                result.BatchSize = PLATFORM_EVENT_SUBSCRIBER_CONFIG_BATCH_SIZE;
                result.Id = null;
                HttpUtils.runToolingPatch(System.Url.getOrgDomainUrl().toExternalForm(), UserInfo.getSessionId(), JSON.serialize(result), ConfigUtil.TOOLING_API_UPDATE_PLATFORM_EVENT_SUBSCRIBER_CONFIG + '/' + recordId);
            }
        }
        return result;
    }

    public class PlatformEventSubscriberConfigWrapper {
        public String Id;
        public String DeveloperName;
        public String MasterLabel;
        public String UserId;
        public String PlatformEventConsumerId;
        public Integer BatchSize;

        public PlatformEventSubscriberConfigWrapper() {}
    }

}