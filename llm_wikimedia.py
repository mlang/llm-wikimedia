from typing import Literal

import click
import httpx
import llm
from xml.etree import ElementTree


Lang = Literal['de', 'en', 'es', 'fr', 'it', 'nl', 'no', 'pt', 'ro']
Site = Literal['wikipedia', 'wiktionary']

export = '{http://www.mediawiki.org/xml/export-0.11/}'

def wikimedia(page: str, lang: Lang = "en", site: Site = "wikipedia"):
    """Fetch a wikimedia article (in Wikimedia format)."""

    with httpx.Client() as client:
        response = client.get(
            f"https://{lang}.{site}.org/w/index.php",
            params={'title': 'Special:Export', 'pages': page},
            follow_redirects=True
        )
        response.raise_for_status()
    wikimedia = ElementTree.fromstring(response.text)
    p = wikimedia.find(f'{export}page')
    if p is None:
        raise RuntimeError(f"There is no page named {page}")
    latest = p.find(f'{export}revision/{export}text')
    if latest is None:
        raise RuntimeError("Could not extract text of latest revision from XML")
    return latest.text


@llm.hookimpl
def register_tools(register):
    register(wikimedia)

@llm.hookimpl
def register_fragment_loaders(register):
    register("wikipedia", lambda article: llm.Fragment(wikimedia(article, "en", "wikipedia")))
    register("wiktionary", lambda article: llm.Fragment(wikimedia(article, "en", "wiktionary")))


@click.command()
@click.option('-l', '--language', default='en', show_default=True)
@click.option('-s', '--site', default='wikipedia', show_default=True)
@click.argument("page")
def cli(page, site, language):
    print(wikimedia(page, language, site))


if __name__ == '__main__':
    cli()
