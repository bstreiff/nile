# Authentication for NILE repos

While the NILE core is available in a public repo, some targets may employ
use of NI-internal repos.

We presently have three classes of resources requiring authentication:

- azdo git repositories at dev.azure.com/ni/Users
    - currently used for certain vivado artifacts
- protected repos under github.com/ni/
    - not presently used, but anticipated for certain products
- protected repos under github.com/EttusResearch/
    - meta-ettus-dev

## `.netrc` authentication with PATs

- Azure DevOps: [Use personal access tokens](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=Windows)
- GitHub: [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

If you need to authenticate to multiple GitHub orgs (e.g. ni and
EttusResearch), you _must_ use a "classic" PAT here, because a combination
of two elements:
- "fine-grained" PATs cannot cross organizations
- `.netrc` is scoped only to hostname, and all orgs under "github.com/" have the same hostname.

Note that you will need to "Authorize" (via the "Configure SSO" option) the PAT
to each organization.

After you've set up your PATs, add the generated tokens to `$HOME/.netrc`:

```
machine dev.azure.com
    login api
    password <azdo token>
machine github.com
    login api
    password <github token>
```

## .gitconfig extraheader authentication with PATs

This is more complicated, but handles the "GitHub orgs all have the same hostname" problem
with GitHub fine-grained PATs.

This approach is more suited for pipelines.

```
git config http.https://github.com/ni/.extraheader \
    "Authorization: Basic `echo -n ni:${AZDO_PAT} | base64 -w 0`"
git config http.https://github.com/EttusResearch/.extraheader \
    "Authorization: Basic `echo -n EttusResearch:${GITHUB_ETTUSRESEARCH_PAT} | base64 -w 0`"
git config http.https://dev.azure.com/ni/Users/.extraheader \
    "Authorization: Basic `echo -n ni:${GITHUB_NI_PAT} | base64 -w 0`"
```
