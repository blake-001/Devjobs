alias Devjobs.Repo
alias Devjobs.Jobs.{Company, Job}

Repo.delete_all(Job)
Repo.delete_all(Company)

lorem =
  "Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Phasellus hendrerit. Pellentesque aliquet nibh nec urna. In nisi neque, aliquet vel, dapibus id, mattis vel, nisi. Sed pretium, ligula sollicitudin laoreet viverra, tortor libero sodales leo, eget blandit nunc tortor eu nibh."

items = [
  "Morbi interdum mollis sapien. Sed",
  "Phasellus lacinia magna a ullamcorper laoreet, lectus arcu pulvinar risus",
  "Mauris nibh felis, adipiscing varius, adipiscing in, lacinia vel, tellus. Suspendisse ac urna. Etiam pellentesque mauris ut lectus.",
  "Morbi interdum mollis sapien. Sed"
]

# {company, color, website, position, contract, location, hours_ago}
data = [
  {"Scoot", "#E99210", "https://scoot.com", "Senior Software Engineer", "Full Time",
   "United Kingdom", 5},
  {"Blogr", "#E95A34", "https://blogr.com", "Haskell and PureScript Dev", "Part Time",
   "United States", 20},
  {"Vector", "#2D3039", "https://vector.com", "Midlevel Back End Engineer", "Part Time", "Russia",
   28},
  {"Office Lite", "#3056D3", "https://officelite.com", "Senior Application Engineer", "Full Time",
   "Japan", 48},
  {"Pod", "#18202D", "https://pod.com", "Remote DevOps Engineer", "Part Time", "Thailand", 52},
  {"Creative", "#5A1F4B", "https://creative.com", "Desktop Support Manager", "Part Time",
   "Germany", 96},
  {"Pomodoro", "#5C2DD5", "https://pomodoro.com", "iOS Engineer", "Full Time", "United States",
   168},
  {"Maker", "#233E73", "https://maker.com", "Senior EJB Developer", "Full Time", "United Kingdom",
   175},
  {"Coffeeroasters", "#F5E6D3", "https://coffeeroasters.com", "Senior Frontend Developer",
   "Part Time", "Singapore", 180},
  {"Mastercraft", "#1B1B1F", "https://mastercraft.com", "App and Website Designer", "Freelance",
   "United States", 336},
  {"Crowdfund", "#35C48F", "https://crowdfund.com", "Fullstack Developer", "Part Time",
   "New Zealand", 720},
  {"Typemaster", "#F26B1F", "https://typemaster.com", "Technical Lead Engineer", "Part Time",
   "United Kingdom", 740},
  {"Loop Studios", "#6C5CE7", "https://loopstudios.com", "Elixir Backend Developer", "Full Time",
   "Kenya", 760},
  {"Kite", "#00B894", "https://kite.dev", "Junior Web Developer", "Freelance", "Germany", 800}
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

for {name, color, site, position, contract, location, hours_ago} <- data do
  company = Repo.insert!(%Company{name: name, logo_background: color, website: site})

  Repo.insert!(%Job{
    company_id: company.id,
    position: position,
    contract: contract,
    location: location,
    description: lorem,
    apply_url: site <> "/careers",
    requirements_content: lorem,
    requirements_items: items,
    role_content: lorem,
    role_items: items,
    posted_at: DateTime.add(now, -hours_ago * 3600, :second)
  })
end

IO.puts("Seeded #{length(data)} jobs")

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Devjobs.Repo.insert!(%Devjobs.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
