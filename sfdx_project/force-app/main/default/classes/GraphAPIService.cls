public with sharing class GraphAPIService {

	public static final String GRAPH_API_SETTINGS_NAME = 'GraphAPI';
	public static String GET_GRAPH_API_TOKEN_ENDPOINT = 'https://login.microsoftonline.com/{0}/oauth2/v2.0/token';
	public static final String GRAPH_API_AUTHORIZE_ENDPOINT = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
	public static final String GRAPH_API_GET_TOKEN_ENDPOINT = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';

	public static final String GRAPH_API_ENPOINT = 'https://graph.microsoft.com/v1.0/';
	public static final String GRAPH_API_GET_ALL_TEAMS_ENDPOINT = GRAPH_API_ENPOINT + 'groups?$select=id,resourceProvisioningOptions,displayName';
	public static final String GRAPH_API_GET_ORGANIZATION_ENDPOINT = GRAPH_API_ENPOINT + 'organization';
	public static String GRAPH_API_GET_TEAM_CHANNELS = GRAPH_API_ENPOINT + '/teams/{0}/channels';
	public static String GRAPH_API_SEND_CHANNEL_MESSAGE = GRAPH_API_ENPOINT + '/teams/{0}/channels/{1}/messages';

	public static final String GRAPH_API_TOKEN_GRANT_TYPE_REFRESH = 'refresh_token';
	public static final String GRAPH_API_TOKEN_GRANT_TYPE_AUTHORIZATION_CODE = 'authorization_code';
	public static final String GRAPH_API_TOKEN_GRANT_TYPE_CLIENT_CREDENTIALS = 'client_credentials';
	public static final String GRAPH_API_TOKEN_RESPONSE_TYPE_CODE = 'code';
	public static final String GRAPH_API_TOKEN_TYPE_BEARER = 'Bearer ';
	public static final String GRAPH_API_TOKEN_RESPONSE_MODE_QUERY = 'query';
	public static String GRAPH_API_SCOPE = 'Directory.AccessAsUser.All Directory.Read.All Directory.ReadWrite.All Group.Read.All Group.ReadWrite.All ' +
		'GroupMember.Read.All Channel.ReadBasic.All ChannelSettings.Read.All ChannelSettings.ReadWrite.All ChannelMessage.Send Chat.ReadWrite ChatMessage.Send offline_access';


	public class GraphAPIServiceException extends Exception {}

	public static List<Team> getTeams() {
		List<Team> result = new List<Team>();

		String b = HttpUtils.get(
			GRAPH_API_GET_ALL_TEAMS_ENDPOINT ,
			HttpUtils.getHeadersAuthorizationAcceptJson(GRAPH_API_TOKEN_TYPE_BEARER + getDecryptedGraphTokenFromCache()),
			200
		);
		TeamRequestWrapper trw = (TeamRequestWrapper)JSON.deserialize(b, TeamRequestWrapper.class);
		result = trw.value;
		return result;
	}

	public static List<Channel> getChannels(String teamId) {
		List<Channel> result = new List<Channel>();

		try {
			String b = HttpUtils.get(
				String.format(GRAPH_API_GET_TEAM_CHANNELS, new List<String>{teamId}),
				HttpUtils.getHeadersAuthorizationAcceptJson(GRAPH_API_TOKEN_TYPE_BEARER + getDecryptedGraphTokenFromCache()),
				200
			);
			TeamChannelWrapper trw = (TeamChannelWrapper)JSON.deserialize(b, TeamChannelWrapper.class);
			result = trw.value;
		}
		catch(HttpUtils.HttpUtilsException e) {}

		return result;
	}

	public static Organization getOrganization(String oAuthToken) {
		Organization result;

		String b = HttpUtils.get(
			GRAPH_API_GET_ORGANIZATION_ENDPOINT ,
			HttpUtils.getHeadersAuthorizationAcceptJson(GRAPH_API_TOKEN_TYPE_BEARER + oAuthToken),
			200
		);
		OrganizationWrapper ow = (OrganizationWrapper)JSON.deserialize(b, OrganizationWrapper.class);
		result = ow.value.get(0);
		return result;
	}

	public class GraphApiSetting {
		public String teamId;
		public String channelId;
		public GraphApiSetting(String teamId){}
		public GraphApiSetting(String teamId, String channelId) {
			this.teamId = teamId;
			this.channelId = channelId;
		}
	}

	public static ChatMessage sendChannelMessage(String teamId, String channelId, ChatMessage chatMessage) {
		ChatMessage result;

		Map<String, String> headers = HttpUtils.getHeadersAuthorizationAcceptJson(GRAPH_API_TOKEN_TYPE_BEARER + getDecryptedGraphTokenFromCache());
		headers.putAll(HttpUtils.getHeadersContentTypeJSON());

		String b = HttpUtils.post(
			String.format(GRAPH_API_SEND_CHANNEL_MESSAGE, new List<String>{teamId, channelId}),
			JSON.serialize(chatMessage),
			headers,
			201
		);
		result = (ChatMessage)JSON.deserialize(b, ChatMessage.class);
		return result;
	}

	public class ChatMessage {
		public String subject;
		public ChatMessageBody body;

		public ChatMessage(){}
		public ChatMessage(String subject, String body) {
			this.subject = subject;
			this.body = new ChatMessageBody();
			this.body.content = body;
			this.body.contentType = 'text';
		}
	}

	public class ChatMessageBody {
		public String content;
		public String contentType;

		public ChatMessageBody(){}
	}

	public class Organization {
		public String id;
		public Organization(String id) {
			this.id = id;
		}
	}

	public class OrganizationWrapper {
		public List<Organization> value;
		public OrganizationWrapper(){}
	}

	public class TeamChannelWrapper {
		public List<Channel> value;
		public TeamChannelWrapper(){}
	}

	public class Channel {
		public String id;
		public String displayName;
		public Channel(String id, String displayName){
			this.id = id;
			this.displayName = displayName;
		}
	}

	public class TeamRequestWrapper {
		public List<Team> value;
		public TeamRequestWrapper(){}
	}

	public class Team {
		public String id;
		public String displayName;
		public List<String> resourceProvisioningOptions;
		public Team(){}
		public Team(String id, String displayName){
			this.id = id;
			this.displayName = displayName;
		}
	}

	@Future(Callout = true)
	public static void validateAndRefreshGraphApiOauthTokenFuture() {
		validateAndRefreshGraphApiOauthToken();
	}

	public static Boolean validateAndRefreshGraphApiOauthToken() {
		return validateAndRefreshGraphApiOauthToken(false);
	}

	public static Boolean validateAndRefreshGraphApiOauthToken(Boolean withDML) {
		Boolean result = false;
		if(PermissionsUtil.TeamsIntegrationEnabled
			&& ConfigUtil.GRAPH_API_SETTINGS.Enabled__c
			&& String.isNotBlank(ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c)) {

			try {
				GraphAPIService.Organization organization = GraphAPIService.getOrganization(GraphAPIService.getDecryptedGraphTokenFromCache());
				result = true;
			}
			catch(HttpUtils.HttpUtilsException e) {
				try {
					refreshOAuthToken(withDML);
					result = true;
				}
				catch(Exception exc) {}
			}
		}
		return result;
	}

	public static void refreshOAuthToken() {
		refreshOAuthToken(true);
	}

	public static void refreshOAuthToken(Boolean withDML) {
		OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GraphAPIService.GRAPH_API_SETTINGS_NAME);
		String endpoint = GraphAPIService.GRAPH_API_GET_TOKEN_ENDPOINT;
		HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_REFRESH_TOKEN, OAUTH_REFRESH_TOKEN);
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_SECRET, mdtSettings.Client_Secret__c);
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_GRANT_TYPE, GRAPH_API_TOKEN_GRANT_TYPE_REFRESH);
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_RESPONSE_TYPE, GRAPH_API_TOKEN_RESPONSE_TYPE_CODE);
		bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_REDIRECT_URI, LoggerSettingsController.PHAROS_OUATH_CALLBACK_PROXY);
		bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, GraphAPIService.GRAPH_API_SCOPE);
		String b = HttpUtils.post(
			endpoint,
			bodyParams.toStringParameters(),
			HttpUtils.getHeadersContentTypeFormUrlencoded(),
			200
		);
		ConnectedOrgService.AuthTokenResponse resp = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);

		GraphAPIService.putEncryptedGraphTokenToCache(ConfigUtil.GRAPH_API_SETTINGS, resp.access_token);
		GraphAPIService.splitToken(resp.refresh_token);

		if(withDML) {
			upsert ConfigUtil.GRAPH_API_SETTINGS;
		}
	}

	public static final String OAUTH_REFRESH_TOKEN {
		get {
			if(OAUTH_REFRESH_TOKEN == null) {
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c != null){
					OAUTH_REFRESH_TOKEN = ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c;
				}
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c != null){
					OAUTH_REFRESH_TOKEN = OAUTH_REFRESH_TOKEN + ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c;
				}
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c != null){
					OAUTH_REFRESH_TOKEN = OAUTH_REFRESH_TOKEN + ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c;
				}
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c != null){
					OAUTH_REFRESH_TOKEN = OAUTH_REFRESH_TOKEN + ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c;
				}
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c != null){
					OAUTH_REFRESH_TOKEN = OAUTH_REFRESH_TOKEN + ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c;
				}
				if(ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c != null){
					OAUTH_REFRESH_TOKEN = OAUTH_REFRESH_TOKEN + ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c;
				}
			}
			return OAUTH_REFRESH_TOKEN;
		}
		set;
	}

	public static String getGraphAPIToken() {
		String result;

		if(String.isNotBlank(ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c)) {
			OAuthSettings__mdt mdtSettings = OAuthSettings__mdt.getInstance(GRAPH_API_SETTINGS_NAME);
			String endpoint = String.format(GET_GRAPH_API_TOKEN_ENDPOINT, new List<String>{ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c});
			HttpUtils.HttpURLParameters bodyParams = new HttpUtils.HttpURLParameters();
			bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_GRANT_TYPE, GRAPH_API_TOKEN_GRANT_TYPE_CLIENT_CREDENTIALS);
			bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_ID, mdtSettings.Client_Id__c);
			bodyParams.addEncodedParameter(HttpUtils.HTTP_URL_PARAM_CLIENT_SECRET, mdtSettings.Client_Secret__c);
			bodyParams.addEncodedParameterWithFixedWhitespace(HttpUtils.HTTP_URL_PARAM_SCOPE, GraphAPIService.GRAPH_API_SCOPE);

			String b = HttpUtils.post(
				endpoint ,
				bodyParams.toStringParameters(),
				HttpUtils.getHeadersContentTypeFormUrlencoded(),
				200
			);
			ConnectedOrgService.AuthTokenResponse graphAppToken = (ConnectedOrgService.AuthTokenResponse)JSON.deserialize(b, ConnectedOrgService.AuthTokenResponse.class);
			result = graphAppToken.access_token;
		}
		return result;
	}

	public static String getGraphInstanceKey(String graphTenantId) {
		return EncodingUtil.base64Encode(Crypto.generateDigest('SHA3-256', Blob.valueOf(String.valueOf(graphTenantId))));
	}

	public static void putEncryptedGraphTokenToCache(Graph_API_Settings__c graphSettings, String token) {
		try {
			if (String.isNotBlank(token)) {
				String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_GRAPH_TOKEN, getGraphInstanceKey(graphSettings.Tenant_Id__c), '');
				Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_GRAPH_TOKEN, keyCache);
				if (isCacheAvailableForKey) {
					Blob encryptedToken = Crypto.encryptWithManagedIV('AES256', EncodingUtil.base64Decode(getGraphInstanceKey(graphSettings.Tenant_Id__c)), Blob.valueOf(token));
					CacheUtils.putCacheValue(keyCache, encryptedToken, CacheUtils.getTTLValue(CacheUtils.KEY_REQUEST_ENCRYPTED_GRAPH_TOKEN));
				}
			}
		} catch (Exception e) {
			Logger.getInstance().internalError(e, graphSettings.Id, true, GraphAPIService.class.getName(), 'putEncryptedGraphTokenToCache');
		}
	}

	public static String getDecryptedGraphTokenFromCache() {
		try {
			String keyCache = CacheUtils.buildCacheKey(CacheUtils.KEY_REQUEST_ENCRYPTED_GRAPH_TOKEN, getGraphInstanceKey(ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c), '');
			Boolean isCacheAvailableForKey = CacheUtils.isCacheAvailableForKey(CacheUtils.KEY_REQUEST_ENCRYPTED_GRAPH_TOKEN, keyCache);
			if (isCacheAvailableForKey) {
				Object cacheObject = CacheUtils.getCacheValue(keyCache);
				if (cacheObject != null) {
					Blob decryptedToken = Crypto.decryptWithManagedIV('AES256', EncodingUtil.base64Decode(getGraphInstanceKey(ConfigUtil.GRAPH_API_SETTINGS.Tenant_Id__c)), (Blob)cacheObject);
					return decryptedToken.toString();
				}
			}
		} catch (Exception e) {
			Logger.getInstance().internalError(e, ConfigUtil.GRAPH_API_SETTINGS.Id, true, GraphAPIService.class.getName(), 'getDecryptedGraphTokenFromCache');
		}
		return null;
	}

	public static final Integer CUSTOM_SETTINGS_FILED_MAX_SIZE = 255;
	public static void splitToken(String token) {
		Integer tokenLength = token.length();
		if(tokenLength > 5*CUSTOM_SETTINGS_FILED_MAX_SIZE){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,4*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c = token.subString(4*CUSTOM_SETTINGS_FILED_MAX_SIZE,5*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token6__c = token.subString(5*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
		}
		else if(tokenLength > 4*CUSTOM_SETTINGS_FILED_MAX_SIZE){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,4*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token5__c = token.subString(4*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
		}
		else if(tokenLength > 3*CUSTOM_SETTINGS_FILED_MAX_SIZE){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,3*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token4__c = token.subString(3*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
		}
		else if(tokenLength > 2*CUSTOM_SETTINGS_FILED_MAX_SIZE){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,2*CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token3__c = token.subString(2*CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
		}
		else if(tokenLength > CUSTOM_SETTINGS_FILED_MAX_SIZE){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,CUSTOM_SETTINGS_FILED_MAX_SIZE);
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token2__c = token.subString(CUSTOM_SETTINGS_FILED_MAX_SIZE,tokenLength);
		}
		else if(tokenLength > 0){
			ConfigUtil.GRAPH_API_SETTINGS.Refresh_Token__c = token.subString(0,tokenLength);
		}
	}
}