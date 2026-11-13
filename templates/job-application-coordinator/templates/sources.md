# Job sources

List the places you want the agent to look, one link per line under "Sources". The agent looks for postings only here. It never picks other sites.

You can list any mix of:
- A search results page you saved, with your keywords, location and filters set.
- A job alert link from an email or a site you use.
- A company career page.
- A link to a single posting.
- A job feed link you chose, for example an RSS or Atom feed, or a JSON feed URL you paste. The agent opens it in the browser like any other source and reads the postings it lists.

You pick every source and you own that choice. The agent never suggests, lists or names feeds or sites. Check that each site's terms allow automated applications.

When a posting links to the employer's own application form, the agent follows that one link and fills the form there, across several pages if needed. It goes no further than that form. A form that needs an account or a login the browser does not have is skipped with the reason "account required".

If a source is down, asks for a login, or shows an error, the agent drops it for the rest of the run and says so in the digest.

The agent checks every source first, then fills forms in score order (see profile.md) until the daily cap.

## Sources

- <paste a link, for example https://jobs.example.com/search?q=backend>
- <paste a feed link, for example https://feeds.example.org/jobs.xml>
