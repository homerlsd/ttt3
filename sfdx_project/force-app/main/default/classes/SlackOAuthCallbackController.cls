public with sharing class SlackOAuthCallbackController {

    public Boolean isCode { get; set; }

    public SlackOAuthCallbackController() {
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
    public static String generateTokenForSlack (String inputJson) {
        Map<String, Object> input = (Map<String, Object>)JSON.deserializeUntyped(inputJson);
        Map<String, Object> output = new Map<String, Object>();
        try {
            String clientId = '2306191770915.2345995700640';
            String clientSecret = 'e209936db1a9000047b7be2560c421ae';
            String endpoint = 'https://slack.com/api/oauth.access';
            String queryParams = '?code=' + EncodingUtil.urlEncode((String)input.get('code'), 'UTF-8')
                + '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8');
            //curl -F code=1234 -F client_id=3336676.569200954261 -F client_secret=ABCDEFGH https://slack.com/api/oauth.v2.access
            //Connected_Org__c corg = ConnectedOrgService.generateTokenForConnectedOrg((String)input.get('code'), input.get('state'), (String)input.get('return_url'));
            String b = HttpUtils.post(
                endpoint + queryParams,
                '',
                null,
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