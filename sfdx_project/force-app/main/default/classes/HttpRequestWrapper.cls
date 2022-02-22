global with sharing class HttpRequestWrapper {

    private final HttpRequest request;
    private final Set<String> HEADER_KEYS = new Set<String>{
            'Accept', 'Accept-CH', 'Accept-Charset', 'Accept-Features', 'Accept-Encoding', 'Accept-Language',
            'Accept-Ranges', 'Access-Control-Allow-Credentials', 'Access-Control-Allow-Origin',
            'Access-Control-Allow-Methods', 'Access-Control-Allow-Headers', 'Access-Control-Max-Age',
            'Access-Control-Expose-Headers', 'Access-Control-Request-Method', 'Access-Control-Request-Headers',
            'Age', 'Allow', 'Alternates', 'Authorization', 'Cache-Control', 'Connection', 'Content-Encoding',
            'Content-Language', 'Content-Length', 'Content-Location', 'Content-MD5', 'Content-Range',
            'Content-Security-Policy', 'Content-Type', 'Cookie', 'DNT', 'Date', 'ETag', 'Expect', 'Expires', 'From',
            'Host', 'If-Match', 'If-Modified-Since', 'If-None-Match', 'If-Range', 'If-Unmodified-Since',
            'Last-Event-ID', 'Last-Modified', 'Link', 'Location', 'Max-Forwards', 'Negotiate', 'Origin', 'Pragma',
            'Proxy-Authenticate', 'Proxy-Authorization', 'Range', 'Referer', 'Retry-After',
            'Sec-Websocket-Extensions', 'Sec-Websocket-Key', 'Sec-Websocket-Origin', 'Sec-Websocket-Protocol',
            'Sec-Websocket-Version', 'Server', 'Set-Cookie', 'Set-Cookie2', 'Strict-Transport-Security', 'TCN',
            'TE', 'Trailer', 'Transfer-Encoding', 'Upgrade', 'User-Agent', 'Variant-Vary', 'Vary', 'Via', 'Warning',
            'WWW-Authenticate', 'X-Content-Duration', 'X-Content-Security-Policy', 'X-DNSPrefetch-Control',
            'X-Frame-Options', 'X-Requested-With', 'X-SFDC-Session'
    };

    /**
	 * Create a new {@code HttpRequest} wrapping the given request object.
	 * @param request -- the request object to be wrapped
	 */
    global HttpRequestWrapper(HttpRequest request) {
        this.request = request;
    }

    /**
	 * Create a new {@code HttpRequest} wrapping the given request object.
	 * @param request -- the request object to be wrapped
	 * @param headerKeys -- the keys of headers to be wrapped
	 */
    public HttpRequestWrapper(HttpRequest request, Set<String> headerKeys) {
        this.request = request;
        this.HEADER_KEYS.addAll(headerKeys);
    }

    /**
	 * @return the wrapped request.
	 */
    public HttpRequest getRequest() {
        return request;
    }

    /**
	 * @return endpoint of the wrapped request.
	 */
    public String getEndpoint() {
        return request.getEndpoint();
    }

    /**
	 * @return method of the wrapped request.
	 */
    public String getMethod() {
        return request.getMethod();
    }

    /**
	 * @return mapHeaders of the wrapped request.
	 */
    public Map<String, String> getHeaders() {
        Map<String, String> mapHeaders = new Map<String, String>();
        for (String key : HEADER_KEYS) {
            if (String.isNotBlank(request.getHeader(key))) {
                mapHeaders.put(key, request.getHeader(key));
            }
        }
        return mapHeaders;
    }

    /**
	 * @return body of the wrapped request.
	 */
    public String getBody() {
        return request.getBody();
    }

    /**
	 * @return compressed of the wrapped request.
	 */
    public Boolean getCompressed() {
        return request.getCompressed();
    }

    /**
	 * @return format request of the wrapped request.
	 */
    global Map<String, Object> formatRequest() {
        if (request == null) return null;
        return new Map<String, Object>{
                'endpoint' => getEndpoint(),
                'method' => getMethod(),
                'headers' => getHeaders(),
                'body' => getBody(),
                'compressed' => getCompressed()
        };
    }

}