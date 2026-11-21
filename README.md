# LiffeyValleyAC

Do you want to add some news? Read [CONTRIBUTING.md](https://github.com/LiffeyValleyAC/LiffeyValleyAC.github.io/blob/master/CONTRIBUTING.md) for the steps.

### Halloween decoration

The small Halloween pumpkin appears beside the social links in the shared header.
To hide it, change the setting in `_config.yml` to:

```yaml
halloween:
  enabled: false
```

Set `enabled: true` to bring it back at any time. This is a manual switch; it
does not depend on the date. Rebuild/deploy the site for the change to appear,
or restart Jekyll when previewing locally.

The decoration is kept in `_includes/halloween-pumpkin.html` and its artwork in
`assets/images/halloween-pumpkin.svg`. It needs no JavaScript or external images.
The SVG includes a gentle side-to-side shake followed by a wink every six seconds.
Edit its `halloween-sway` and `halloween-wink` keyframes to adjust the movement
and expression. Both animations respect the visitor's reduced-motion preference.

### Local Development

You should have the following version of `ruby` and `gem` installed.
- ruby `>2.50` (working on windows with `2.6.8)
- gem (working on windows with `3.0.3.1`) 

To run the site locally, for testing, you can install the required libraries with:

```
script/bootstrap
```

Then run the server with:

```
script/server
```

By default, this will serve the page on http://127.0.0.1:4000 after building it.
