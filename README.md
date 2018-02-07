# atomx - Atomx API Client

*Author:* Daniel Kraus <daniel@atomx.com><br>
*Version:* 0.1<br>
*URL:* [https://github.com/atomx/atomx-api-elisp](https://github.com/atomx/atomx-api-elisp)<br>

Interface for the atomx rest api.

You have to set `atomx-email` and `atomx-password` to your
atomx api credentials either by setting those variables directly
or by adding a line like the following to your `.authinfo` / `.authinfo.gpg`
"machine api.atomx.com login yourname@example.com password your-atomx-pass"

To use in elisp you first have to call `atomx-login` before you can
request resources from the api.
E.g. Login, get the publishers list and show the name of the first:

    (atomx-login)

    (atomx-get
     'publisher
     (lambda (p)
       (message "First publisher name: %s"
                (assoc-default 'name (aref atomx-pub 0)))))

Usage with restclient:
You must have an `:api` variable in your restclient buffer that specifies
the atomx api endpoint, e.g.:

    :api = https://sandbox-api.atomx.com/v3

and an `:auth-token` variable that holds the value of the auth-token.

Then you can just call <kbd>M-x atomx-restclient-update-auth-token</kbd>
and atomx.el will parse the `:api` variable, get the correct
login info from your `.authinfo.gpg`, fetch a new auth token
and set `:auth-token` accordingly.


---
Converted from `atomx.el` by [*el2markdown*](https://github.com/Lindydancer/el2markdown).
