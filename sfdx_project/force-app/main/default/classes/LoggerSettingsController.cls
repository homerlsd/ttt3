public with sharing class LoggerSettingsController {

    public Connected_Orgs_Settings__c settings { get; set; }
    public Boolean hasConnectedApp { get; set; }
    public Boolean isCode { get; set; }
    public Boolean isSandbox { get; set; }

    public LoggerSettingsController() {
        this.init();
        this.isCode = String.isNotBlank(ApexPages.currentPage().getParameters().get('code'));
        this.isSandbox = ConfigUtil.currentOrgIsSandbox;
    }

    private void init() {
        this.settings = ConfigUtil.CONNECTED_ORGS_SETTINGS;
        hasConnectedApp = String.isNotBlank(ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Key__c) && String.isNotBlank(ConfigUtil.CONNECTED_ORGS_SETTINGS.Client_Secret__c);
    }

    @RemoteAction
    public static String generateTokenForConnectedOrg (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            Connected_Org__c corg = ConnectedOrgService.generateTokenForConnectedOrg((String)input.get('code'), input.get('state'), (String)input.get('redirectUrl'));
            output.put('status', 'ok');
            output.put('corg', corg);
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }

    public static final String SLACK_OAUTH_ENDPOINT = 'https://slack.com/api/oauth.access';
    public static final String SLACK_SETTINGS_NAME = 'Slack';

    @RemoteAction
    public static String generateTokenForSlack (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_API_URL, ConfigUtil.REMOTE_SITE_SETTINGS_SLACK_DESCRIPTION);

            OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(SLACK_SETTINGS_NAME);
            String endpoint = SLACK_OAUTH_ENDPOINT;
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CODE, (String)input.get('code'));
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_SECRET, mdtSettings.Client_Secret__c);
            String b = HttpUtils.post(
                    endpoint,
                    bodyParams.toStringParameters(),
                    null,
                    200
            );
            ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);
            ConfigUtil.SLACK_SETTINGS.Slack_API_Token__c = resp.access_token;
            ConfigUtil.SLACK_SETTINGS.Slack_Enabled__c = true;
            upsert ConfigUtil.SLACK_SETTINGS;

            output.put('status', 'ok');
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }

    @RemoteAction
    public static String generateTokenForGraph (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_URL, ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_TOKEN_REQUEST_DESCRIPTION);
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_URL, ConfigUtil.REMOTE_SITE_SETTINGS_GRAPH_API_REQUEST_DESCRIPTION);

            OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GraphAPIService.GRAPH_API_SETTINGS_NAME);
            String endpoint = GraphAPIService.GRAPH_API_GET_TOKEN_ENDPOINT;
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CODE, (String)input.get('code'));
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_SECRET, mdtSettings.Client_Secret__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_GRANT_TYPE, GraphAPIService.GRAPH_API_TOKEN_GRANT_TYPE_AUTHORIZATION_CODE);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_RESPONSE_TYPE, GraphAPIService.GRAPH_API_TOKEN_RESPONSE_TYPE_CODE);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, (String)input.get('return_url'));
            bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, GraphAPIService.GRAPH_API_SCOPE);

            String b = HttpUtils.post(
                endpoint,
                bodyParams.toStringParameters(),
                HttpUtils.getHeadersContentTypeFormUrlencoded(),
                200
            );
            ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);

            GraphAPIService.Organization organization = GraphAPIService.getOrganization(resp.access_token);
            ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c = organization.id;

            GraphAPIService.putEncryptedGraphTokenToCache(ConfigUtil.GRAPH_API_SETTINGS, resp.access_token);

            GraphAPIService.splitToken(resp.refresh_token);
            upsert ConfigUtil.GRAPH_API_SETTINGS;

            output.put('status', 'ok');
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }

    @RemoteAction
    public static String generateTokenForGitHub (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_API_URL, ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_API_DESCRIPTION);
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_URL, ConfigUtil.REMOTE_SITE_SETTINGS_GIT_HUB_DESCRIPTION);

            OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GitHubUtils.GIT_API_SETTINGS_NAME);
            String endpoint = GitHubUtils.GIT_API_TOKEN_ENDPOINT;
            HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CODE, (String)input.get('code'));
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_SECRET, mdtSettings.Client_Secret__c);
            bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, (String)input.get('return_url'));

            String b = HttpUtils.post(
                endpoint,
                bodyParams.toStringParameters(),
                HttpUtils.getHeadersAcceptJson(),
                200
            );
            ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);
            GitHubUtils.GitUserInfo userInfo = GitHubUtils.getGitUserInfo('token ' + resp.access_token);
            ConfigUtil.GIT_API_SETTINGS.oAuth_Token__c = resp.access_token;
            ConfigUtil.GIT_API_SETTINGS.Username__c = userInfo.login;
            ConfigUtil.GIT_API_SETTINGS.Enabled__c = true;
            upsert ConfigUtil.GIT_API_SETTINGS;

            output.put('status', 'ok');
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }

    public static final String PHAROS_OUATH_CALLBACK_PROXY {
        get {
            return 'https://auth.pharos.ai';
        }
    }

    @RemoteAction
    public static String generateTokenForJira (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            // remote site settings for cloud api / oauth endpoint
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_NAME, ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_URL, ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_CLOUD_API_DESCRIPTION);
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_CLOUD_OAUTH_NAME, ConfigUtil.JIRA_CLOUD_OAUTH_ENDPOINT, ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_CLOUD_OAUTH_DESCRIPTION);

            OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(ConfigUtil.JIRA_CLOUD_SETTINGS_NAME);
            String clientId = mdtSettings.Client_Id__c;
            String clientSecret = mdtSettings.Client_Secret__c;
            String endpoint = ConfigUtil.JIRA_CLOUD_OAUTH_ENDPOINT;
            String oAuthCode = (String)input.get('code');

            ConnectedOrgService.AuthTokenResponse resp = JiraService.getJiraAPIToken(oAuthCode, clientId, clientSecret, endpoint);

            // get cloud site url
            ConfigUtil.JiraResourceWrapper jiraSite = JiraService.getJiraEndpoint(resp.access_token);
            // remote site settings for cloud site url
            AdminService.upsertRemoteSiteSetting(ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_NAME, jiraSite.url, ConfigUtil.REMOTE_SITE_SETTINGS_JIRA_DESCRIPTION);

            ConfigUtil.JIRA_SETTINGS.Jira_API_Url__c = ConfigUtil.JIRA_CLOUD_API_PREFIX + jiraSite.id;
            ConfigUtil.JIRA_SETTINGS.Jira_Base_Url__c = jiraSite.url;
            ConfigUtil.JIRA_SETTINGS.Jira_Username__c = ConfigUtil.JIRA_CLOUD_OAUTH_USERNAME;

            JiraService.splitToken(resp.access_token);
            ConfigUtil.JIRA_SETTINGS.Refresh_Token__c = resp.refresh_token;

            JiraService.putEncryptedJiraTokenToCache(ConfigUtil.JIRA_SETTINGS, resp.access_token);
            JiraService.putEncryptedJiraRefreshTokenToCache(ConfigUtil.JIRA_SETTINGS, resp.refresh_token);
            upsert ConfigUtil.JIRA_SETTINGS;

            output.put('status', 'ok');
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }

}