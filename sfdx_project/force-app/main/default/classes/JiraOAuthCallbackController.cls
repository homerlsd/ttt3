public with sharing class JiraOAuthCallbackController {
    public Boolean isCode { get; set; }

    public JiraOAuthCallbackController() {
        Map<String,String> params = ApexPages.currentPage().getParameters();
        system.debug('---params-'+json.serialize(params));
        this.isCode = String.isNotBlank(ApexPages.currentPage().getParameters().get('code'));
    }


    public class AuthTokenResponse {
        public String access_token;
        public String refresh_token;
        public String signature;
        public String scope;
        public String instance_url;
        public String id;
        public String token_type;
        public String issued_at;
    }

    @RemoteAction
    public static String generateTokenForJira (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            String clientId = 'gEnErOjkydU6k5usCUBnXXlKaB9t21Tb';
            String clientSecret = 'mSY8n25LvdmusZBIRmACp5xMJNzVDwDN-84lMR08SRYlgcnG4V-KKadIfBNKtGyV';
            String endpoint = 'https://auth.atlassian.com/oauth/token';
//            String queryParams = '?code=' + EncodingUtil.urlEncode((String)input.get('code'), 'UTF-8')
//                    + '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8')
//                    + '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            //curl -F code=1234 -F client_id=3336676.569200954261 -F client_secret=ABCDEFGH https://slack.com/api/oauth.v2.access
            //Connected_Org__c corg = ConnectedOrgService.generateTokenForConnectedOrg((String)input.get('code'), input.get('state'), (String)input.get('return_url'));
            Map<String, String> headers = new Map<String, String>{
                'Content-Type' => 'application/json'
            };
            //'{"grant_type": "authorization_code","client_id": "YOUR_CLIENT_ID","client_secret": "YOUR_CLIENT_SECRET","code": "YOUR_AUTHORIZATION_CODE","redirect_uri": "https://YOUR_APP_CALLBACK_URL"}'
            Map<String, Object> body = new Map<String, Object>{
                'grant_type' => 'authorization_code',
                'client_id' => clientId,
                'client_secret' => clientSecret,
                'code' => (String)input.get('code'),
                'redirect_uri' => 'https://7s9zkaxdxg.execute-api.us-west-1.amazonaws.com'
            };
            String b = HttpUtils.post(
                endpoint ,
                json.serialize(body),
                headers,
                200
            );
            system.debug('--b--'+b);

            AuthTokenResponse resp = (AuthTokenResponse)JSON.deserialize(b, AuthTokenResponse.class);

            output.put('status', 'ok');
            output.put('corg', resp.access_token);
        } catch(Exception e) {
            output.put('status', 'error');
            output.put('message', e.getMessage());
        }
        return JSON.serialize(output);
    }
}