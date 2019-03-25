module SimpleButton = {
  open Style;

  let component = ReasonReact.statelessComponent("CodaNav.SimpleButton");
  let make = (~name, ~link, _children) => {
    ...component,
    render: _self => {
      <a
        href=link
        className=Css.(
          merge([
            Body.basic,
            style(
              Style.paddingY(`rem(0.75))
              @ [
                margin(`zero),
                textDecoration(`none),
                whiteSpace(`nowrap),
                hover([color(Style.Colors.hyperlinkHover)]),
              ],
            ),
          ])
        )>
        {ReasonReact.string(name)}
      </a>;
    },
  };
};

module SignupButton = {
  open Style;

  let component = ReasonReact.statelessComponent("CodaNav.SignupButton");
  let make = (~name, ~link, _children) => {
    ...component,
    render: _self => {
      <a
        href=link
        className=Css.(
          merge([
            H4.wide,
            style(
              paddingX(`rem(1.0))
              @ paddingY(`rem(0.75))
              @ [
                width(`rem(6.25)),
                height(`rem(2.5)),
                borderRadius(`px(5)),
                color(Style.Colors.hyperlink),
                border(`px(1), `solid, Style.Colors.hyperlink),
                textDecoration(`none),
                whiteSpace(`nowrap),
                hover([
                  backgroundColor(Style.Colors.hyperlink),
                  color(Style.Colors.whiteAlpha(0.95)),
                ]),
                // Make this display the same as a SimpleButton
                // when the screen is small enough to show a menu
                media(
                  Nav.NavStyle.MediaQuery.menuMax,
                  [
                    height(`auto),
                    paddingLeft(`rem(0.)),
                    paddingRight(`zero),
                    borderWidth(`zero),
                    Typeface.ibmplexsans,
                    color(Colors.metallicBlue),
                    fontSize(`rem(1.0)),
                    lineHeight(`rem(1.5)),
                    fontWeight(`normal),
                    letterSpacing(`rem(0.)),
                    fontStyle(`normal),
                    textTransform(`none),
                    hover([
                      backgroundColor(`transparent),
                      color(Style.Colors.hyperlinkHover),
                    ]),
                  ],
                ),
              ],
            ),
          ])
        )>
        {ReasonReact.string(name)}
      </a>;
    },
  };
};

let component = ReasonReact.statelessComponent("CodaNav");
let make = _children => {
  ...component,
  render: _self => {
    <Nav>
      <SimpleButton name="Blog" link="/blog.html" />
      <SimpleButton name="Testnet" link="/testnet.html" />
      <SimpleButton name="GitHub" link="/code.html" />
      <SimpleButton name="Careers" link="/jobs.html" />
      <SignupButton name="Sign up" link=Links.mailingList />
    </Nav>;
  },
};
