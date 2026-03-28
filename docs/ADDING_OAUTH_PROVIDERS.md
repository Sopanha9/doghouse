# Adding OAuth Providers to Dogehouse

This guide explains how to add new OAuth login providers (e.g., Google, Facebook, Apple, etc.) to the Dogehouse application.

## Current OAuth Providers

The application currently supports:

- **GitHub** - Fully implemented
- **X (Twitter)** - Fully implemented
- **Discord** - Fully implemented
- **Google** - Fully implemented

## Architecture Overview

The authentication system uses:

- **Backend**: Elixir/Phoenix with Ueberauth library
- **Frontend**: Next.js/React with OAuth redirect flow
- **Database**: PostgreSQL with user schema storing OAuth IDs

## Step-by-Step Guide to Add a New OAuth Provider

### 1. Backend Changes (kousa/)

#### 1.1 Add Ueberauth Strategy Dependency

Edit [`kousa/mix.exs`](kousa/mix.exs) and add the appropriate Ueberauth strategy:

```elixir
# Example for Google (already present)
{:ueberauth_google, "~> 0.10"}

# Example for Facebook
{:ueberauth_facebook, "~> 0.10"}

# Example for Apple
{:ueberauth_apple, "~> 0.3"}

# Example for LinkedIn
{:ueberauth_linkedin, "~> 0.3"}
```

Run `mix deps.get` to fetch the new dependency.

#### 1.2 Configure OAuth Provider

Edit [`kousa/config/dev.exs`](kousa/config/dev.exs) and add configuration:

```elixir
# Example for Google (already present)
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID") || raise("GOOGLE_CLIENT_ID is missing"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || raise("GOOGLE_CLIENT_SECRET is missing")

# Example for Facebook
config :ueberauth, Ueberauth.Strategy.Facebook.OAuth,
  client_id: System.get_env("FACEBOOK_CLIENT_ID") || raise("FACEBOOK_CLIENT_ID is missing"),
  client_secret: System.get_env("FACEBOOK_CLIENT_SECRET") || raise("FACEBOOK_CLIENT_SECRET is missing")
```

Also add to [`kousa/config/releases.exs`](kousa/config/releases.exs) for production.

#### 1.3 Add Database Migration (if needed)

If the provider requires new fields in the users table, create a migration:

```bash
cd kousa
mix ecto.gen.migrate add_facebook_fields
```

Example migration:

```elixir
defmodule Beef.Repo.Migrations.AddFacebookFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :facebookId, :string
      add :facebookAccessToken, :string
    end

    create unique_index(:users, [:facebookId])
  end
end
```

#### 1.4 Update User Schema

Edit [`kousa/lib/beef/schemas/user.ex`](kousa/lib/beef/schemas/user.ex):

```elixir
# Add to schema
field(:facebookId, :string)
field(:facebookAccessToken, :string)

# Update @type t
@type t :: %__MODULE__{
  # ... existing fields
  facebookId: String.t(),
  facebookAccessToken: String.t(),
  # ...
}
```

#### 1.5 Create Auth Route

Create a new file `kousa/lib/broth/routes/facebook_auth.ex`:

```elixir
defmodule Broth.Routes.FacebookAuth do
  import Plug.Conn
  use Plug.Router

  require Logger
  alias Beef.Users

  plug(:match)
  plug(:dispatch)

  get "/web" do
    state =
      if Application.get_env(:kousa, :staging?) do
        %{
          redirect_base_url: fetch_query_params(conn).query_params["redirect_after_base"]
        }
        |> Jason.encode!()
        |> Base.encode64()
      else
        "web"
      end

    %{conn | params: Map.put(conn.params, "state", state)}
    |> Plug.Conn.put_private(:ueberauth_request_options, %{
      callback_url: Application.get_env(:kousa, :api_url) <> "/auth/facebook/callback",
      options: [
        default_scope: "email,public_profile"
      ]
    })
    |> Ueberauth.Strategy.Facebook.handle_request!()
  end

  get "/callback" do
    conn
    |> fetch_query_params()
    |> Plug.Conn.put_private(:ueberauth_request_options, %{
      options: []
    })
    |> Ueberauth.Strategy.Facebook.handle_callback!()
    |> handle_callback()
  end

  def get_base_url(conn) do
    with state <- Map.get(conn.query_params, "state", ""),
         {:ok, json} <- Base.decode64(state),
         {:ok, %{"redirect_base_url" => redirect_base_url}} when is_binary(redirect_base_url) <-
           Jason.decode(json) do
      redirect_base_url
    else
      _ ->
        Application.fetch_env!(:kousa, :web_url)
    end
  end

  def handle_callback(
        %Plug.Conn{assigns: %{ueberauth_failure: %{errors: [%{message_key: "missing_code"}]}}} =
          conn
      ) do
    conn
    |> Broth.Plugs.Redirect.redirect(
      get_base_url(conn) <>
        "/?error=" <>
        URI.encode("try again")
    )
  end

  def handle_callback(%Plug.Conn{assigns: %{ueberauth_failure: failure}} = conn) do
    Logger.warn("facebook oauth failure: #{inspect(failure)}")

    conn
    |> Broth.Plugs.Redirect.redirect(
      get_base_url(conn) <>
        "/?error=" <>
        URI.encode(
          "something went wrong, try again and if the error persists, tell ben to check the server logs"
        )
    )
  end

  def handle_callback(
        %Plug.Conn{private: %{facebook_user: user, facebook_token: %{access_token: access_token}}} =
          conn
      ) do
    try do
      {_, db_user} = Users.facebook_find_or_create(user, access_token)

      if not is_nil(db_user.reasonForBan) do
        conn
        |> Broth.Plugs.Redirect.redirect(
          get_base_url(conn) <>
            "/?error=" <>
            URI.encode(
              "your account got banned, if you think this was a mistake, please send me an email at benawadapps@gmail.com"
            )
        )
      else
        conn
        |> Broth.Plugs.Redirect.redirect(
          get_base_url(conn) <>
            "/?accessToken=" <>
            Kousa.AccessToken.generate_and_sign!(%{"userId" => db_user.id}) <>
            "&refreshToken=" <>
            Kousa.RefreshToken.generate_and_sign!(%{
              "userId" => db_user.id,
              "tokenVersion" => db_user.tokenVersion
            })
        )
      end
    rescue
      e in RuntimeError ->
        conn
        |> Broth.Plugs.Redirect.redirect(
          get_base_url(conn) <>
            "/?error=" <>
            URI.encode(e.message)
        )
    end
  end

  def handle_callback(conn) do
    Logger.warn("unhandled handle_callback #{inspect(conn)}")

    conn
    |> Broth.Plugs.Redirect.redirect(
      get_base_url(conn) <>
        "/?error=" <>
        URI.encode(
          "something went wrong, try again and if the error persists, tell ben to check the server logs"
        )
    )
  end
end
```

#### 1.6 Add Find or Create Function

Edit [`kousa/lib/beef/mutations/users.ex`](kousa/lib/beef/mutations/users.ex):

```elixir
def facebook_find_or_create(user, facebook_access_token) do
  facebookId = user["id"]

  db_user =
    from(u in User,
      where: u.facebookId == ^facebookId,
      limit: 1
    )
    |> Repo.one()

  if db_user do
    if is_nil(db_user.facebookId) do
      from(u in User,
        where: u.id == ^db_user.id,
        update: [
          set: [
            facebookId: ^facebookId,
            facebookAccessToken: ^facebook_access_token
          ]
        ]
      )
      |> Repo.update_all([])
    end

    {:find, db_user}
  else
    {:create,
     Repo.insert!(
       %User{
         username: Kousa.Utils.Random.big_ascii_id(),
         facebookId: facebookId,
         email: if(user["email"] == "", do: nil, else: user["email"]),
         facebookAccessToken: facebook_access_token,
         avatarUrl: user["picture"]["data"]["url"],
         displayName: user["name"],
         hasLoggedIn: true
       },
       returning: true
     )}
  end
end
```

#### 1.7 Register Route in Router

Edit [`kousa/lib/broth.ex`](kousa/lib/broth.ex):

```elixir
alias Broth.Routes.FacebookAuth

# Add to router
forward("/auth/facebook", to: FacebookAuth)
```

#### 1.8 Add to Users Module

Edit [`kousa/lib/beef/users.ex`](kousa/lib/beef/users.ex):

```elixir
defdelegate facebook_find_or_create(user, facebook_access_token), to: Beef.Mutations.Users
```

### 2. Frontend Changes (kibbeh/)

#### 2.1 Add OAuth Icon

Create a new icon file `kibbeh/src/icons/SolidFacebook.tsx`:

```tsx
import React from "react";

interface SolidFacebookProps {
  width?: number;
  height?: number;
  className?: string;
}

export const SolidFacebook: React.FC<SolidFacebookProps> = ({
  width = 20,
  height = 20,
  className = "",
}) => {
  return (
    <svg
      width={width}
      height={height}
      viewBox="0 0 24 24"
      fill="currentColor"
      className={className}
    >
      <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
    </svg>
  );
};
```

Export it in [`kibbeh/src/icons/index.tsx`](kibbeh/src/icons/index.tsx):

```tsx
export { SolidFacebook } from "./SolidFacebook";
```

#### 2.2 Update Login Page

Edit [`kibbeh/src/modules/landing-page/LoginPage.tsx`](kibbeh/src/modules/landing-page/LoginPage.tsx):

```tsx
import { SolidFacebook } from "../../icons";

// Add to the login buttons section
<LoginButton oauthUrl={`${apiBaseUrl}/auth/facebook/web${queryParams}`}>
  <SolidFacebook width={20} height={20} />
  Log in with Facebook
</LoginButton>;
```

### 3. Environment Variables

Add to [`kousa.env.example`](kousa.env.example):

```bash
# Facebook OAuth
FACEBOOK_CLIENT_ID=replace-me
FACEBOOK_CLIENT_SECRET=replace-me
```

### 4. Testing

1. Set up OAuth credentials with the provider
2. Add environment variables
3. Start the backend: `cd kousa && mix phx.server`
4. Start the frontend: `cd kibbeh && yarn dev`
5. Navigate to the login page and test the new provider

## Common OAuth Providers

### Google (Fully Implemented)

The project has:

- Ueberauth dependency in mix.exs
- Configuration in dev.exs and releases.exs
- Google icon in frontend
- `google_auth.ex` route file
- `google_find_or_create` function
- Database fields (googleId, googleAccessToken)
- Frontend login button

### Facebook

Requires:

- Facebook Developer account
- OAuth credentials
- Ueberauth Facebook strategy

### Apple

Requires:

- Apple Developer account
- Sign in with Apple capability
- Ueberauth Apple strategy

### LinkedIn

Requires:

- LinkedIn Developer account
- OAuth credentials
- Ueberauth LinkedIn strategy

## Troubleshooting

### Common Issues

1. **Missing environment variables**: Ensure all required OAuth credentials are set
2. **Callback URL mismatch**: Verify the callback URL in OAuth provider settings matches `API_URL/auth/{provider}/callback`
3. **Scope issues**: Check that the OAuth scopes request the necessary permissions (email, profile, etc.)
4. **Database constraints**: Ensure unique indexes exist for provider IDs

### Debugging

Enable debug logging in [`kousa/config/dev.exs`](kousa/config/dev.exs):

```elixir
config :logger, level: :debug
```

Check Ueberauth logs for OAuth flow details.

## References

- [Ueberauth Documentation](https://hexdocs.pm/ueberauth/)
- [Ueberauth Strategies](https://hexdocs.pm/ueberauth/strategies.html)
- [GitHub Auth Implementation](kousa/lib/broth/routes/github_auth.ex)
- [X (Twitter) Auth Implementation](kousa/lib/broth/routes/twitter_auth.ex)
- [Google Auth Implementation](kousa/lib/broth/routes/google_auth.ex)
- [Discord Auth Implementation](kousa/lib/broth/routes/discord_auth.ex)
