// Houston demo jobs (data for scripts/generate_houston_seed.ts). All companies are fictional;
// websites use example.com. Requirement syntax, one string per skill (names from skills.csv):
//   "Python 2y"    required, at least 2 years, weight 2
//   "Python 2y !"  required, weight 3 (core skill)
//   "~Docker"      preferred, weight 1
// Hourly roles store annualized pay (rate × hours × 52) because the app shows salary per year;
// the description states the hourly rate.

export type Remote = "onsite" | "hybrid" | "remote";
export type JobType = "full_time" | "part_time" | "contract" | "internship";

export interface Company {
  key: string;
  name: string;
  website: string;
  verified: boolean;
  hq: string;
  industry: string;
  blurb: string;
}

export interface JobSpec {
  company: string;
  title: string;
  location: string;
  remote: Remote;
  type: JobType;
  /** Annual salary range in USD. */
  salary?: [number, number];
  /** Hourly range in USD and hours per week (annualized for salary_min/max). */
  hourly?: [number, number, number];
  sponsorship?: boolean;
  summary: string;
  duties: string[];
  reqs: string[];
}

export const COMPANIES: Company[] = [
  {
    key: "buffalo-bayou-energy",
    name: "Buffalo Bayou Energy",
    website: "https://buffalobayouenergy.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Energy",
    blurb:
      "Buffalo Bayou Energy is a fictional mid-size oil and gas operator headquartered in the Energy Corridor. Our digital team builds the software that engineers use to monitor production, plan maintenance, and cut emissions across 1,200 wells.",
  },
  {
    key: "ship-channel-renewables",
    name: "Ship Channel Renewables",
    website: "https://shipchannelrenewables.example.com",
    verified: false,
    hq: "Pasadena, TX",
    industry: "Renewable energy",
    blurb:
      "Ship Channel Renewables develops and operates grid-scale battery storage and solar sites along the Houston Ship Channel. We are a 90-person team that sells power into the ERCOT market.",
  },
  {
    key: "braeswood-health",
    name: "Braeswood Health System",
    website: "https://braeswoodhealth.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Healthcare",
    blurb:
      "Braeswood Health System is a fictional nonprofit academic hospital system in the Texas Medical Center area, with four hospitals and 30 clinics across Greater Houston. Our IT group supports 14,000 employees and the patient app used by 300,000 Houstonians.",
  },
  {
    key: "brays-bayou-bio",
    name: "Brays Bayou BioAnalytics",
    website: "https://braysbayoubio.example.com",
    verified: false,
    hq: "Houston, TX",
    industry: "Biotech research",
    blurb:
      "Brays Bayou BioAnalytics is a genomics research lab spun out of a medical center partnership. We run sequencing pipelines for cancer research groups and build analysis tools for scientists.",
  },
  {
    key: "clear-lake-orbital",
    name: "Clear Lake Orbital Systems",
    website: "https://clearlakeorbital.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Aerospace",
    blurb:
      "Clear Lake Orbital Systems builds flight software, simulators, and mission-control tools for crewed and cargo spacecraft. Our 400 engineers work out of the Clear Lake and Webster area.",
  },
  {
    key: "ellington-launch",
    name: "Ellington Launch Dynamics",
    website: "https://ellingtonlaunch.example.com",
    verified: false,
    hq: "Houston, TX",
    industry: "Aerospace startup",
    blurb:
      "Ellington Launch Dynamics is a 60-person startup at the Houston spaceport building small reusable suborbital vehicles for research payloads.",
  },
  {
    key: "galveston-bay-freight",
    name: "Galveston Bay Freight Works",
    website: "https://galvestonbayfreight.example.com",
    verified: true,
    hq: "La Porte, TX",
    industry: "Logistics and port",
    blurb:
      "Galveston Bay Freight Works runs container yard, drayage, and warehousing operations around the Port of Houston, moving about 400,000 containers a year.",
  },
  {
    key: "allens-landing-bank",
    name: "Allen's Landing Bank",
    website: "https://allenslandingbank.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Banking",
    blurb:
      "Allen's Landing Bank is a fictional Texas regional bank headquartered downtown, serving 600,000 consumer and small-business customers through 85 branches and a growing digital bank.",
  },
  {
    key: "westheimer-pay",
    name: "Westheimer Pay",
    website: "https://westheimerpay.example.com",
    verified: false,
    hq: "Houston, TX",
    industry: "Fintech",
    blurb:
      "Westheimer Pay is a Series A fintech startup in Montrose building payments and payroll tools for Houston's restaurants and small businesses.",
  },
  {
    key: "station-nine-software",
    name: "Station Nine Software",
    website: "https://stationnine.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Software",
    blurb:
      "Station Nine Software is a product studio in Midtown's innovation district. We design and build web, mobile, and AI products for Houston startups and enterprises.",
  },
  {
    key: "sabine-rusk-consulting",
    name: "Sabine & Rusk Consulting",
    website: "https://sabinerusk.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Consulting",
    blurb:
      "Sabine & Rusk Consulting is a 250-person technology and data consultancy serving energy, healthcare, and public-sector clients across Texas.",
  },
  {
    key: "post-oak-market",
    name: "Post Oak Market Co.",
    website: "https://postoakmarket.example.com",
    verified: false,
    hq: "Houston, TX",
    industry: "Retail",
    blurb:
      "Post Oak Market Co. is a fictional home-goods retailer with 40 stores across Texas and a fast-growing online store, headquartered in Uptown Houston.",
  },
  {
    key: "bayou-region-water",
    name: "Bayou Region Water Authority",
    website: "https://bayouregionwater.example.com",
    verified: true,
    hq: "Houston, TX",
    industry: "Public sector",
    blurb:
      "Bayou Region Water Authority is a fictional public utility providing drinking water, drainage, and flood data to two million residents of the Houston region.",
  },
  {
    key: "oyster-creek-devices",
    name: "Oyster Creek Devices",
    website: "https://oystercreekdevices.example.com",
    verified: false,
    hq: "Sugar Land, TX",
    industry: "Consumer IoT",
    blurb:
      "Oyster Creek Devices designs connected home-safety sensors (flood, smoke, and freeze detectors) and the apps that go with them, from our office in Sugar Land.",
  },
  {
    key: "woodlands-subsea",
    name: "Woodlands Subsea Robotics",
    website: "https://woodlandssubsea.example.com",
    verified: true,
    hq: "The Woodlands, TX",
    industry: "Robotics",
    blurb:
      "Woodlands Subsea Robotics builds autonomous underwater vehicles that inspect offshore pipelines and wind-farm foundations in the Gulf.",
  },
  {
    key: "katy-prairie-insurance",
    name: "Katy Prairie Insurance",
    website: "https://katyprairieinsurance.example.com",
    verified: false,
    hq: "Katy, TX",
    industry: "Insurance",
    blurb:
      "Katy Prairie Insurance is a fictional home and auto insurer serving Texas Gulf Coast families. After every hurricane season we rebuild more of our claims process in software.",
  },
  {
    key: "barton-springs-analytics",
    name: "Barton Springs Analytics",
    website: "https://bartonspringsanalytics.example.com",
    verified: false,
    hq: "Austin, TX",
    industry: "Data and AI",
    blurb:
      "Barton Springs Analytics is a remote-first Austin startup that helps mid-size retailers forecast demand and price products with machine learning.",
  },
  {
    key: "alamo-heights-cyber",
    name: "Alamo Heights Cyber",
    website: "https://alamoheightscyber.example.com",
    verified: true,
    hq: "San Antonio, TX",
    industry: "Cybersecurity",
    blurb:
      "Alamo Heights Cyber is a managed security provider in San Antonio that runs a 24/7 security operations center for hospitals, utilities, and city governments across Texas.",
  },
];

export const JOBS: JobSpec[] = [
  // --- Buffalo Bayou Energy -----------------------------------------------------------------
  {
    company: "buffalo-bayou-energy",
    title: "Software Engineer I, Production Operations",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [85000, 105000],
    summary:
      "Join a small team building the internal web apps that production engineers use every morning to spot underperforming wells and schedule field crews.",
    duties: [
      "Build features in our Python services and React dashboards",
      "Write SQL against our production historian and well database",
      "Ship small changes weekly and learn from engineers in the field",
    ],
    reqs: [
      "Python 1y !",
      "SQL 1y",
      "Git",
      "~React",
      "~REST APIs",
      "~Microsoft Azure",
    ],
  },
  {
    company: "buffalo-bayou-energy",
    title: "Data Engineer, Subsurface Data Platform",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [120000, 150000],
    sponsorship: true,
    summary:
      "Own the pipelines that bring seismic, well-log, and drilling data into our lakehouse so geoscientists and data scientists can trust what they query.",
    duties: [
      "Build and operate Spark pipelines on Databricks",
      "Model subsurface data for analytics and machine learning",
      "Add data-quality checks and on-call runbooks",
    ],
    reqs: [
      "Python 3y !",
      "SQL 3y",
      "Apache Spark 2y",
      "Databricks 1y",
      "Microsoft Azure 2y",
      "~Apache Airflow",
      "~Delta Lake",
      "~Data Modeling",
    ],
  },
  {
    company: "buffalo-bayou-energy",
    title: "Machine Learning Engineer, Predictive Maintenance",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [135000, 170000],
    summary:
      "Predict compressor and pump failures before they happen. You will take models from notebook to production and measure the downtime they save.",
    duties: [
      "Train time-series and anomaly-detection models on sensor data",
      "Deploy and monitor models with MLflow",
      "Work with reliability engineers to turn predictions into work orders",
    ],
    reqs: [
      "Python 4y !",
      "Machine Learning 3y !",
      "scikit-learn 2y",
      "Time Series Analysis 2y",
      "~PyTorch",
      "~MLflow",
      "~Anomaly Detection",
      "~Docker",
    ],
  },
  {
    company: "buffalo-bayou-energy",
    title: "Software Engineering Intern (Summer 2027)",
    location: "Houston, TX",
    remote: "onsite",
    type: "internship",
    hourly: [30, 34, 40],
    summary:
      "A 12-week paid internship on our digital operations team. Interns ship a real project, present it to leadership, and most receive return offers.",
    duties: [
      "Build a small tool or dashboard used by field engineers",
      "Pair with a mentor on code reviews and testing",
      "Present your project at the end-of-summer showcase",
    ],
    reqs: [
      "Python !",
      "Data Structures",
      "Git",
      "~SQL",
      "~JavaScript",
      "~Linux",
    ],
  },
  {
    company: "buffalo-bayou-energy",
    title: "SCADA Integration Engineer",
    location: "Katy, TX",
    remote: "onsite",
    type: "full_time",
    salary: [105000, 130000],
    summary:
      "Connect field automation to our operations center. You will integrate PLCs and RTUs at new well pads and keep the control network secure.",
    duties: [
      "Configure SCADA tags, alarms, and historian links for new sites",
      "Troubleshoot PLC and network issues with field technicians",
      "Harden control-network security with our OT security team",
    ],
    reqs: [
      "SCADA 3y !",
      "PLC Programming 2y",
      "Networking 2y",
      "~Python",
      "~Microsoft SQL Server",
      "~Network Security",
    ],
  },
  {
    company: "buffalo-bayou-energy",
    title: "Senior Cloud Platform Engineer",
    location: "Houston, TX",
    remote: "remote",
    type: "full_time",
    salary: [150000, 185000],
    sponsorship: true,
    summary:
      "Lead the Azure landing zone and Kubernetes platform that 20 product teams deploy to. Remote within Texas, with quarterly on-sites in Houston.",
    duties: [
      "Design and evolve our Terraform-managed Azure platform",
      "Run AKS clusters and the deployment pipelines around them",
      "Mentor engineers and set platform standards",
    ],
    reqs: [
      "Microsoft Azure 5y !",
      "Terraform 3y",
      "Kubernetes 3y",
      "Azure DevOps 3y",
      "~Helm",
      "~Observability",
      "~Python",
      "~Technical Leadership",
    ],
  },

  // --- Ship Channel Renewables ----------------------------------------------------------------
  {
    company: "ship-channel-renewables",
    title: "Battery Storage Data Analyst",
    location: "Pasadena, TX",
    remote: "onsite",
    type: "full_time",
    salary: [70000, 85000],
    summary:
      "Turn battery telemetry and ERCOT market data into reports that tell our traders and site managers how each asset is performing.",
    duties: [
      "Build Power BI reports on asset availability and revenue",
      "Analyze charge and discharge patterns in SQL and Python",
      "Flag underperforming battery strings to the operations team",
    ],
    reqs: [
      "Data Analysis 1y !",
      "SQL 1y",
      "Python",
      "Power BI",
      "~Time Series Analysis",
      "~Microsoft Excel",
    ],
  },
  {
    company: "ship-channel-renewables",
    title: "Embedded Software Engineer, Battery Management",
    location: "Pasadena, TX",
    remote: "onsite",
    type: "full_time",
    salary: [110000, 135000],
    summary:
      "Write the firmware that keeps thousands of lithium-ion cells safe, balanced, and talking to our site controllers.",
    duties: [
      "Develop and test battery-management firmware in C",
      "Build hardware-in-the-loop tests with the controls team",
      "Investigate field faults from site logs",
    ],
    reqs: [
      "C 3y !",
      "Embedded Systems 3y",
      "C++ 2y",
      "~Control Systems",
      "~Python",
      "~Git",
    ],
  },
  {
    company: "ship-channel-renewables",
    title: "Full-Stack Developer, Energy Trading Dashboard",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [100000, 125000],
    summary:
      "Build the real-time dashboard our traders use to bid batteries into the ERCOT market every five minutes.",
    duties: [
      "Build React and TypeScript views over live market data",
      "Write Node.js services backed by PostgreSQL",
      "Make charts fast enough for five-minute trading intervals",
    ],
    reqs: [
      "React 2y !",
      "TypeScript 2y",
      "Node.js 2y",
      "PostgreSQL 1y",
      "~Docker",
      "~WebSockets",
      "~D3.js",
    ],
  },
  {
    company: "ship-channel-renewables",
    title: "GIS Technician (Part-Time)",
    location: "Pasadena, TX",
    remote: "onsite",
    type: "part_time",
    hourly: [22, 26, 20],
    summary:
      "Help our development team map land parcels, transmission lines, and flood zones for new solar and storage sites. Great fit for a geography or engineering student.",
    duties: [
      "Maintain parcel and site layers in our GIS",
      "Prepare maps for permitting packages",
      "Clean up survey data in spreadsheets",
    ],
    reqs: [
      "Geographic Information Systems 1y !",
      "Microsoft Excel",
      "~Python",
      "~SQL",
    ],
  },

  // --- Braeswood Health System ----------------------------------------------------------------
  {
    company: "braeswood-health",
    title: "Healthcare IT Analyst",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [75000, 92000],
    summary:
      "Be the bridge between clinicians and IT. You will gather requirements, configure clinical workflows, and support go-lives across our hospitals.",
    duties: [
      "Gather requirements from nurses, physicians, and pharmacists",
      "Write SQL to validate clinical data and reports",
      "Write test scripts and support go-lives",
    ],
    reqs: [
      "Healthcare IT 1y !",
      "SQL 1y",
      "HIPAA Compliance",
      "~Microsoft Excel",
      "~Jira",
      "~Technical Writing",
    ],
  },
  {
    company: "braeswood-health",
    title: "Mobile Developer (Flutter), Patient App",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [105000, 130000],
    summary:
      "Build the Braeswood patient app: appointments, test results, messaging, and bill pay for 300,000 patients on iOS and Android.",
    duties: [
      "Ship Flutter features end to end with design and backend partners",
      "Make every screen accessible and fast on older phones",
      "Protect patient data in line with HIPAA",
    ],
    reqs: [
      "Flutter 2y !",
      "Dart 2y",
      "REST APIs 1y",
      "~Firebase",
      "~Accessibility",
      "~HIPAA Compliance",
      "~Push Notifications",
      "~Git",
    ],
  },
  {
    company: "braeswood-health",
    title: "Clinical Data Engineer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [115000, 140000],
    sponsorship: true,
    summary:
      "Move clinical data from the EHR into our research and quality warehouse, so researchers and quality teams can trust what they measure.",
    duties: [
      "Build ETL from the EHR into SQL Server and Azure",
      "Model encounters, labs, and medications for analytics",
      "Apply de-identification and HIPAA controls",
    ],
    reqs: [
      "SQL 3y !",
      "Python 2y",
      "ETL 2y",
      "Microsoft SQL Server 2y",
      "~Azure Data Factory",
      "~Healthcare IT",
      "~HIPAA Compliance",
      "~dbt",
    ],
  },
  {
    company: "braeswood-health",
    title: "IT Help Desk Technician (Part-Time, Evenings)",
    location: "Pearland, TX",
    remote: "onsite",
    type: "part_time",
    hourly: [19, 23, 24],
    summary:
      "Keep clinic staff working on evening and weekend shifts. Ideal for students in IT or computer science who want hospital IT experience.",
    duties: [
      "Reset accounts and troubleshoot workstations and printers",
      "Image and deploy laptops for new staff",
      "Document fixes in our ticketing system",
    ],
    reqs: [
      "Windows Server",
      "Active Directory",
      "Networking",
      "~Linux",
      "~Microsoft Excel",
    ],
  },
  {
    company: "braeswood-health",
    title: "Security Analyst, Identity & Access",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [95000, 115000],
    summary:
      "Make sure the right people (and only the right people) can reach patient records across 14,000 accounts.",
    duties: [
      "Run access reviews and joiner/mover/leaver automation",
      "Investigate suspicious sign-ins from our SIEM",
      "Script fixes in PowerShell",
    ],
    reqs: [
      "Identity and Access Management 2y !",
      "Microsoft Entra ID 1y",
      "SIEM 1y",
      "~HIPAA Compliance",
      "~PowerShell",
      "~Splunk",
    ],
  },
  {
    company: "braeswood-health",
    title: "Data Science Intern, Patient Flow",
    location: "Houston, TX",
    remote: "hybrid",
    type: "internship",
    hourly: [27, 31, 40],
    summary:
      "Help our emergency departments predict surges. You will analyze arrival patterns and prototype a forecast that charge nurses can use.",
    duties: [
      "Explore and clean de-identified ED visit data",
      "Build and evaluate a simple forecasting model",
      "Present findings to clinical operations leaders",
    ],
    reqs: [
      "Python !",
      "Statistics",
      "SQL",
      "~Pandas",
      "~Data Visualization",
      "~Machine Learning",
    ],
  },
  {
    company: "braeswood-health",
    title: "Senior .NET Developer, EHR Integrations",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [135000, 160000],
    summary:
      "Lead development of the services that connect our EHR to labs, pharmacies, and partner hospitals.",
    duties: [
      "Design and build ASP.NET Core integration services",
      "Own reliability of interfaces that move millions of messages a day",
      "Review code and mentor two mid-level developers",
    ],
    reqs: [
      "C# 5y !",
      ".NET 5y",
      "ASP.NET Core 3y",
      "Microsoft SQL Server 3y",
      "REST APIs 3y",
      "~Healthcare IT",
      "~Microsoft Azure",
      "~Unit Testing",
    ],
  },

  // --- Brays Bayou BioAnalytics -----------------------------------------------------------------
  {
    company: "brays-bayou-bio",
    title: "Bioinformatics Software Engineer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [110000, 135000],
    summary:
      "Build and scale the sequencing pipelines behind dozens of cancer research studies.",
    duties: [
      "Write and maintain Python pipelines on our HPC cluster and AWS",
      "Package tools in containers for reproducibility",
      "Work with scientists to turn analyses into reusable tools",
    ],
    reqs: [
      "Python 3y !",
      "Bioinformatics 2y !",
      "Linux 2y",
      "~R",
      "~Docker",
      "~High-Performance Computing",
      "~AWS",
    ],
  },
  {
    company: "brays-bayou-bio",
    title: "Research Data Analyst (Contract)",
    location: "Houston, TX",
    remote: "remote",
    type: "contract",
    hourly: [40, 50, 40],
    summary:
      "A six-month contract analyzing clinical-trial and genomic data for a pancreatic cancer study.",
    duties: [
      "Clean and merge trial datasets in R",
      "Run statistical analyses and produce publication figures",
      "Document methods for the study team",
    ],
    reqs: [
      "R 2y !",
      "Statistics 2y",
      "SQL 1y",
      "~tidyverse",
      "~ggplot2",
      "~Python",
    ],
  },

  // --- Clear Lake Orbital Systems ---------------------------------------------------------------
  {
    company: "clear-lake-orbital",
    title: "Flight Software Engineer",
    location: "Webster, TX",
    remote: "onsite",
    type: "full_time",
    salary: [115000, 145000],
    summary:
      "Write and verify the C++ flight software that runs on cargo spacecraft. U.S. person status is required because of export regulations.",
    duties: [
      "Develop flight software for guidance and vehicle health",
      "Write unit and hardware-in-the-loop tests",
      "Support integration and mission simulations",
    ],
    reqs: [
      "C++ 3y !",
      "Embedded Systems 2y",
      "Linux 2y",
      "~Avionics Software",
      "~Python",
      "~Unit Testing",
      "~Git",
    ],
  },
  {
    company: "clear-lake-orbital",
    title: "Software Engineering Intern, Mission Control Tools",
    location: "Houston, TX",
    remote: "onsite",
    type: "internship",
    hourly: [28, 32, 40],
    summary:
      "Spend the summer building tools that flight controllers use to monitor spacecraft telemetry.",
    duties: [
      "Build a telemetry display or automation script with your mentor",
      "Write tests and documentation",
      "Watch real mission simulations from the control room",
    ],
    reqs: [
      "Python !",
      "Object-Oriented Programming",
      "Git",
      "~JavaScript",
      "~React",
      "~Linux",
    ],
  },
  {
    company: "clear-lake-orbital",
    title: "Ground Systems DevOps Engineer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [120000, 145000],
    summary:
      "Automate and monitor the Linux ground systems that talk to spacecraft around the clock.",
    duties: [
      "Automate server builds with Ansible",
      "Run containerized ground software and its CI/CD pipelines",
      "Build monitoring dashboards and alerting",
    ],
    reqs: [
      "Linux 3y !",
      "Ansible 2y",
      "Docker 2y",
      "CI/CD 2y",
      "~GitLab CI",
      "~Python",
      "~Prometheus",
      "~Grafana",
    ],
  },
  {
    company: "clear-lake-orbital",
    title: "Guidance, Navigation & Control Engineer",
    location: "Webster, TX",
    remote: "onsite",
    type: "full_time",
    salary: [125000, 155000],
    summary:
      "Design and simulate the control laws that dock spacecraft safely.",
    duties: [
      "Develop GN&C algorithms in MATLAB",
      "Port verified algorithms to flight C++",
      "Run Monte Carlo analyses for mission reviews",
    ],
    reqs: [
      "MATLAB 3y !",
      "Control Systems 3y !",
      "C++ 2y",
      "~Python",
      "~Signal Processing",
      "~Linear Algebra",
    ],
  },
  {
    company: "clear-lake-orbital",
    title: "Technical Writer, Spacecraft Procedures (Contract)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "contract",
    hourly: [45, 55, 40],
    summary:
      "A 12-month contract writing and maintaining the operating procedures that flight controllers follow during missions.",
    duties: [
      "Write procedures with engineers and flight controllers",
      "Maintain procedures in Confluence and our XML authoring system",
      "Run reviews and track changes",
    ],
    reqs: ["Technical Writing 3y !", "Confluence", "~Jira", "~XML", "~Git"],
  },
  {
    company: "clear-lake-orbital",
    title: "Senior Simulation Software Engineer",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [155000, 185000],
    summary:
      "Lead the C++ simulator that astronauts and flight controllers train on.",
    duties: [
      "Architect simulator rendering and physics improvements",
      "Profile and optimize real-time performance",
      "Lead a team of five engineers",
    ],
    reqs: [
      "C++ 6y !",
      "Computer Graphics 3y",
      "OpenGL 3y",
      "Linux 4y",
      "~Python",
      "~Qt",
      "~High-Performance Computing",
      "~Technical Leadership",
    ],
  },

  // --- Ellington Launch Dynamics -----------------------------------------------------------------
  {
    company: "ellington-launch",
    title: "Junior Full-Stack Engineer",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [80000, 98000],
    summary:
      "Build the web tools our launch team uses to plan flights, track parts, and review test data. Startup pace, real rockets.",
    duties: [
      "Build React screens and Node.js APIs",
      "Work directly with propulsion and test engineers",
      "Own features from idea to production",
    ],
    reqs: [
      "React 1y !",
      "JavaScript 1y",
      "Node.js 1y",
      "~TypeScript",
      "~PostgreSQL",
      "~Git",
    ],
  },
  {
    company: "ellington-launch",
    title: "Test Automation Engineer, Avionics",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [95000, 118000],
    summary:
      "Automate the test stands that qualify our avionics before every flight.",
    duties: [
      "Write Python test automation for avionics hardware",
      "Build pytest suites that run in CI on every change",
      "Analyze test data and file clear bug reports",
    ],
    reqs: [
      "Python 2y !",
      "Test Automation 2y",
      "pytest 1y",
      "~Linux",
      "~LabVIEW",
      "~CI/CD",
    ],
  },
  {
    company: "ellington-launch",
    title: "Data Visualization Intern",
    location: "Houston, TX",
    remote: "hybrid",
    type: "internship",
    hourly: [22, 25, 20],
    summary:
      "A part-time fall internship building dashboards that show engine test-fire data to engineers minutes after each test.",
    duties: [
      "Build interactive charts of sensor data",
      "Automate data loading from test runs",
      "Present dashboards to the propulsion team",
    ],
    reqs: ["Python !", "Data Visualization", "~Plotly", "~D3.js", "~SQL"],
  },

  // --- Galveston Bay Freight Works -------------------------------------------------------------
  {
    company: "galveston-bay-freight",
    title: "Logistics Software Engineer, Terminal Operations",
    location: "La Porte, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [95000, 120000],
    summary:
      "Build the Java services that schedule trucks, cranes, and yard moves at our container terminals.",
    duties: [
      "Build Spring Boot services for gate and yard operations",
      "Publish and consume container events on Kafka",
      "Work on site with terminal supervisors to fix real bottlenecks",
    ],
    reqs: [
      "Java 2y !",
      "Spring Boot 2y",
      "SQL 2y",
      "~Apache Kafka",
      "~Docker",
      "~Microservices",
    ],
  },
  {
    company: "galveston-bay-freight",
    title: "Supply Chain Data Analyst",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [72000, 88000],
    summary:
      "Find where containers wait and why. Your analysis will decide where we add trucks, chassis, and people.",
    duties: [
      "Build Tableau dashboards on dwell time and turn times",
      "Write SQL against our terminal and trucking systems",
      "Present recommendations to operations managers",
    ],
    reqs: [
      "SQL 1y !",
      "Microsoft Excel 1y",
      "Tableau 1y",
      "~Python",
      "~Data Analysis",
      "~Operations Research",
    ],
  },
  {
    company: "galveston-bay-freight",
    title: "IoT Engineer, Container Tracking",
    location: "La Porte, TX",
    remote: "onsite",
    type: "full_time",
    salary: [105000, 130000],
    summary:
      "Put trackers on chassis and reefers and turn their signals into live location and temperature data.",
    duties: [
      "Prototype and deploy tracking devices with hardware partners",
      "Stream device data into AWS",
      "Build alerts for temperature excursions on refrigerated containers",
    ],
    reqs: [
      "Internet of Things 2y !",
      "Python 2y",
      "AWS 1y",
      "~Bluetooth Low Energy",
      "~Embedded Linux",
      "~Amazon Kinesis",
    ],
  },
  {
    company: "galveston-bay-freight",
    title: "Network Administrator",
    location: "Pasadena, TX",
    remote: "onsite",
    type: "full_time",
    salary: [78000, 95000],
    summary:
      "Keep the terminal network running, from gate cameras to crane wireless, at three sites.",
    duties: [
      "Run Cisco switching, routing, and wireless",
      "Manage VPNs to partner sites",
      "Respond to outages with the operations team",
    ],
    reqs: [
      "Cisco Networking 2y !",
      "Networking 3y",
      "Windows Server 2y",
      "~VPN",
      "~Network Security",
      "~Linux",
    ],
  },

  // --- Allen's Landing Bank -----------------------------------------------------------------------
  {
    company: "allens-landing-bank",
    title: "Associate Software Engineer, Digital Banking",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [88000, 105000],
    sponsorship: true,
    summary:
      "Start your career on the team behind our online and mobile banking, with a structured two-year development program.",
    duties: [
      "Build Java services and Angular screens for digital banking",
      "Write tests and take part in code reviews",
      "Rotate across payments, lending, and security teams",
    ],
    reqs: [
      "Java 1y !",
      "SQL",
      "Object-Oriented Programming",
      "~Spring Boot",
      "~Angular",
      "~Git",
      "~Agile",
    ],
  },
  {
    company: "allens-landing-bank",
    title: "Senior Backend Engineer, Payments",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [150000, 180000],
    sponsorship: true,
    summary:
      "Lead design of the real-time payments platform that moves billions of dollars a year.",
    duties: [
      "Design event-driven payment services on Kafka",
      "Own reliability, observability, and incident response",
      "Mentor engineers and lead architecture reviews",
    ],
    reqs: [
      "Java 5y !",
      "Spring Boot 4y",
      "Microservices 3y",
      "PostgreSQL 3y",
      "Apache Kafka 2y",
      "~Payments",
      "~AWS",
      "~Kubernetes",
    ],
  },
  {
    company: "allens-landing-bank",
    title: "Fraud Analytics Data Scientist",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [120000, 145000],
    summary:
      "Catch card and account fraud faster without blocking good customers.",
    duties: [
      "Build and monitor fraud-detection models",
      "Engineer features from transaction and device data",
      "Explain model decisions to risk and compliance partners",
    ],
    reqs: [
      "Python 3y !",
      "Machine Learning 2y !",
      "SQL 2y",
      "~XGBoost",
      "~Anomaly Detection",
      "~Fintech",
      "~Snowflake",
    ],
  },
  {
    company: "allens-landing-bank",
    title: "Business Intelligence Analyst",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [80000, 98000],
    summary:
      "Give branch and product leaders the numbers they run the bank on.",
    duties: [
      "Build and maintain Power BI dashboards",
      "Write SQL and model data for self-service reporting",
      "Answer ad hoc questions from executives",
    ],
    reqs: [
      "Power BI 2y !",
      "SQL 2y",
      "Microsoft Excel 2y",
      "~Data Modeling",
      "~Business Intelligence",
    ],
  },
  {
    company: "allens-landing-bank",
    title: "Cybersecurity Analyst I",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [82000, 98000],
    summary:
      "Protect customer accounts as part of the bank's security operations team.",
    duties: [
      "Triage alerts in our SIEM and escalate incidents",
      "Investigate phishing and account-takeover attempts",
      "Improve detections and playbooks",
    ],
    reqs: [
      "Cybersecurity 1y !",
      "SIEM",
      "Networking",
      "~Splunk",
      "~Incident Management",
      "~Linux",
      "~NIST Cybersecurity Framework",
    ],
  },
  {
    company: "allens-landing-bank",
    title: "Technology Analyst Intern",
    location: "Houston, TX",
    remote: "onsite",
    type: "internship",
    hourly: [26, 30, 40],
    summary:
      "A 10-week summer internship rotating between software, data, and security teams downtown.",
    duties: [
      "Work on a real project with an engineering team",
      "Write SQL and scripts to automate reports",
      "Join intern cohort events and leadership talks",
    ],
    reqs: ["SQL", "Microsoft Excel", "~Python", "~Java", "~Agile"],
  },

  // --- Westheimer Pay -------------------------------------------------------------------------------
  {
    company: "westheimer-pay",
    title: "Mobile Engineer (React Native)",
    location: "Houston, TX",
    remote: "remote",
    type: "full_time",
    salary: [115000, 140000],
    summary:
      "Build the app restaurant owners use to run payroll and see the day's sales.",
    duties: [
      "Ship React Native features on iOS and Android",
      "Write tests and keep releases smooth",
      "Talk to restaurant owners and turn feedback into features",
    ],
    reqs: [
      "React Native 2y !",
      "TypeScript 2y",
      "~Expo",
      "~Jest",
      "~Payments",
      "~App Store Deployment",
    ],
  },
  {
    company: "westheimer-pay",
    title: "Backend Engineer (Go)",
    location: "Houston, TX",
    remote: "remote",
    type: "full_time",
    salary: [125000, 155000],
    summary:
      "Build the ledger and payout services behind every paycheck we process.",
    duties: [
      "Write Go services and PostgreSQL schemas",
      "Integrate with banking and card partners",
      "Keep money movement correct, idempotent, and auditable",
    ],
    reqs: [
      "Go 2y !",
      "PostgreSQL 2y",
      "REST APIs 2y",
      "~gRPC",
      "~Docker",
      "~Stripe",
      "~Plaid",
    ],
  },
  {
    company: "westheimer-pay",
    title: "Product Designer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [95000, 120000],
    summary:
      "Design simple payroll and payments flows for busy restaurant owners, in English and Spanish.",
    duties: [
      "Design flows and high-fidelity screens in Figma",
      "Run interviews and usability tests with customers",
      "Grow our design system",
    ],
    reqs: [
      "Figma 2y !",
      "UI Design 2y",
      "Prototyping 1y",
      "~UX Research",
      "~Design Systems",
      "~Accessibility",
    ],
  },
  {
    company: "westheimer-pay",
    title: "QA Engineer (Contract-to-Hire)",
    location: "Houston, TX",
    remote: "remote",
    type: "contract",
    hourly: [45, 58, 40],
    summary:
      "A six-month contract-to-hire role building our first automated test suite.",
    duties: [
      "Write Cypress end-to-end tests for the web dashboard",
      "Test APIs with Postman and automated checks",
      "Own the regression checklist for each release",
    ],
    reqs: [
      "Test Automation 2y !",
      "Cypress 1y",
      "API Testing 1y",
      "~Postman",
      "~JavaScript",
      "~Regression Testing",
    ],
  },

  // --- Station Nine Software ------------------------------------------------------------------------
  {
    company: "station-nine-software",
    title: "Junior Flutter Developer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [75000, 92000],
    summary:
      "Build Flutter apps for our clients, from a hospital wayfinding app to a field-service tool for an energy company.",
    duties: [
      "Build screens and state management in Flutter",
      "Connect apps to REST, Firebase, and Supabase backends",
      "Pair with senior developers and grow through code review",
    ],
    reqs: [
      "Flutter 1y !",
      "Dart 1y",
      "Git",
      "~Firebase",
      "~Riverpod",
      "~REST APIs",
      "~Supabase",
    ],
  },
  {
    company: "station-nine-software",
    title: "Software Engineering Intern (Web & Mobile)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "internship",
    hourly: [25, 28, 40],
    summary:
      "Spend a summer on a real client project with one of our product squads.",
    duties: [
      "Build features in React or Flutter",
      "Take part in standups, demos, and retros",
      "Ship to real users before the summer ends",
    ],
    reqs: [
      "JavaScript",
      "Git",
      "~React",
      "~Flutter",
      "~HTML",
      "~CSS",
      "~Python",
    ],
  },
  {
    company: "station-nine-software",
    title: "Frontend Engineer (React)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [100000, 125000],
    summary: "Build fast, accessible web apps for client products.",
    duties: [
      "Build React and Next.js interfaces",
      "Write component and accessibility tests",
      "Work closely with designers on details",
    ],
    reqs: [
      "React 2y !",
      "TypeScript 2y",
      "CSS 2y",
      "~Next.js",
      "~Testing Library",
      "~Accessibility",
      "~Tailwind CSS",
    ],
  },
  {
    company: "station-nine-software",
    title: "Senior Full-Stack Engineer",
    location: "Houston, TX",
    remote: "remote",
    type: "full_time",
    salary: [145000, 175000],
    summary:
      "Lead technical design for client products from the first sketch to launch.",
    duties: [
      "Architect TypeScript web apps and APIs",
      "Lead a squad of three to five engineers",
      "Advise clients on technical tradeoffs",
    ],
    reqs: [
      "TypeScript 5y !",
      "React 4y",
      "Node.js 4y",
      "PostgreSQL 3y",
      "System Design 3y",
      "~AWS",
      "~GraphQL",
      "~Mentoring",
    ],
  },
  {
    company: "station-nine-software",
    title: "Web Developer (Part-Time, Students Welcome)",
    location: "Houston, TX",
    remote: "remote",
    type: "part_time",
    hourly: [20, 25, 20],
    summary:
      "Build marketing sites and landing pages for client launches, around your class schedule.",
    duties: [
      "Build responsive pages from Figma designs",
      "Fix bugs and improve page speed",
      "Learn from our full-time engineers",
    ],
    reqs: ["HTML", "CSS", "JavaScript", "~React", "~Responsive Design", "~SEO"],
  },
  {
    company: "station-nine-software",
    title: "AI Engineer, LLM Features",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [130000, 160000],
    summary:
      "Build AI features for client products: search, summarization, and assistants built on large language models.",
    duties: [
      "Build retrieval-augmented generation pipelines in Python",
      "Evaluate prompts and models against real tasks",
      "Ship LLM features behind FastAPI services",
    ],
    reqs: [
      "Python 3y !",
      "Large Language Models 1y !",
      "Retrieval-Augmented Generation 1y",
      "~LangChain",
      "~Vector Databases",
      "~Prompt Engineering",
      "~FastAPI",
      "~pgvector",
    ],
  },

  // --- Sabine & Rusk Consulting ----------------------------------------------------------------------
  {
    company: "sabine-rusk-consulting",
    title: "Technology Consultant (Analyst)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [78000, 92000],
    summary:
      "Start your consulting career helping Houston clients modernize systems and use their data.",
    duties: [
      "Analyze client processes and data",
      "Build reports and write recommendations",
      "Support system implementations as part of a project team",
    ],
    reqs: [
      "SQL",
      "Microsoft Excel 1y",
      "Agile",
      "~Power BI",
      "~Python",
      "~Technical Writing",
    ],
  },
  {
    company: "sabine-rusk-consulting",
    title: "Data & Analytics Consultant",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [105000, 130000],
    summary:
      "Design and build modern data platforms for energy and healthcare clients.",
    duties: [
      "Build Snowflake and dbt data models",
      "Lead requirements sessions with client stakeholders",
      "Deliver dashboards that answer real business questions",
    ],
    reqs: [
      "SQL 3y !",
      "Snowflake 2y",
      "dbt 1y",
      "Data Modeling 2y",
      "~Tableau",
      "~Python",
      "~Fivetran",
    ],
  },
  {
    company: "sabine-rusk-consulting",
    title: "Cloud Migration Consultant (Contract)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "contract",
    hourly: [70, 90, 40],
    summary:
      "A nine-month contract moving a public-sector client's data center workloads to AWS.",
    duties: [
      "Plan migration waves and landing zones",
      "Write Terraform for target environments",
      "Lead cutovers and hypercare",
    ],
    reqs: [
      "AWS 4y !",
      "Cloud Migration 3y !",
      "Terraform 2y",
      "~Linux",
      "~Windows Server",
      "~Cloud Architecture",
    ],
  },
  {
    company: "sabine-rusk-consulting",
    title: "Project Manager, Software Implementations",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [110000, 135000],
    summary:
      "Run agile delivery for enterprise software rollouts at energy and utility clients.",
    duties: [
      "Plan sprints and releases with client and consultant teams",
      "Track scope, budget, and risk",
      "Keep stakeholders informed and aligned",
    ],
    reqs: [
      "Agile 3y !",
      "Scrum 3y",
      "Jira 2y",
      "~Confluence",
      "~SAFe",
      "~Software Development Life Cycle",
    ],
  },
  {
    company: "sabine-rusk-consulting",
    title: "Business Analyst Intern",
    location: "Houston, TX",
    remote: "onsite",
    type: "internship",
    hourly: [23, 26, 40],
    summary:
      "A summer internship supporting client projects, open to business, MIS, and engineering students.",
    duties: [
      "Analyze client data in Excel",
      "Document requirements and process maps",
      "Build a final presentation for a client team",
    ],
    reqs: [
      "Microsoft Excel",
      "Data Analysis",
      "~SQL",
      "~Power BI",
      "~Technical Writing",
    ],
  },

  // --- Post Oak Market Co. ----------------------------------------------------------------------------
  {
    company: "post-oak-market",
    title: "E-commerce Web Developer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [90000, 112000],
    summary: "Build the online store that now brings in a third of our sales.",
    duties: [
      "Build product, cart, and checkout features",
      "Improve page speed and search rankings",
      "Run experiments with the marketing team",
    ],
    reqs: [
      "JavaScript 2y !",
      "React 1y",
      "E-commerce 1y",
      "~Next.js",
      "~Stripe",
      "~SEO",
      "~Web Performance",
    ],
  },
  {
    company: "post-oak-market",
    title: "Marketing Analytics Analyst",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [70000, 86000],
    summary: "Measure what our campaigns actually sell, online and in stores.",
    duties: [
      "Build reports on campaign and channel performance",
      "Analyze A/B tests on the website",
      "Recommend where to spend the next marketing dollar",
    ],
    reqs: [
      "Google Analytics 1y !",
      "SQL 1y",
      "Microsoft Excel",
      "~A/B Testing",
      "~Looker",
      "~Python",
    ],
  },
  {
    company: "post-oak-market",
    title: "Store Systems Technician (Part-Time)",
    location: "Katy, TX",
    remote: "onsite",
    type: "part_time",
    hourly: [18, 22, 25],
    summary:
      "Keep point-of-sale systems, Wi-Fi, and devices working across our west Houston stores.",
    duties: [
      "Install and troubleshoot store networks and devices",
      "Set up registers and handheld scanners",
      "Escalate outages to the central IT team",
    ],
    reqs: ["Networking", "Linux", "~Active Directory", "~Raspberry Pi"],
  },
  {
    company: "post-oak-market",
    title: "Machine Learning Engineer, Recommendations",
    location: "Houston, TX",
    remote: "remote",
    type: "full_time",
    salary: [135000, 165000],
    summary:
      "Build the recommendations that help shoppers find the right sofa, rug, or lamp.",
    duties: [
      "Train and serve recommendation models",
      "Build features from browsing and purchase data",
      "Run online experiments to measure impact",
    ],
    reqs: [
      "Python 3y !",
      "Recommender Systems 2y !",
      "PyTorch 2y",
      "SQL 2y",
      "~Apache Spark",
      "~Feature Engineering",
      "~AWS",
    ],
  },
  {
    company: "post-oak-market",
    title: "UX Researcher (Contract)",
    location: "Houston, TX",
    remote: "hybrid",
    type: "contract",
    hourly: [50, 62, 40],
    summary:
      "A four-month contract studying how customers shop across our stores, website, and app.",
    duties: [
      "Plan and run interviews and usability studies",
      "Synthesize findings into clear recommendations",
      "Partner with designers on prototypes",
    ],
    reqs: [
      "UX Research 3y !",
      "Figma 1y",
      "~A/B Testing",
      "~Accessibility",
      "~Human-Computer Interaction",
    ],
  },

  // --- Bayou Region Water Authority -------------------------------------------------------------------
  {
    company: "bayou-region-water",
    title: "GIS Developer",
    location: "Houston, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [78000, 95000],
    summary:
      "Build the maps and tools residents and crews use to track flooding, outages, and water main repairs.",
    duties: [
      "Build web maps and GIS automation in Python",
      "Maintain spatial data in PostgreSQL",
      "Support emergency operations during storms",
    ],
    reqs: [
      "Geographic Information Systems 2y !",
      "Python 2y",
      "SQL 1y",
      "~Leaflet",
      "~PostgreSQL",
      "~JavaScript",
    ],
  },
  {
    company: "bayou-region-water",
    title: "Systems Administrator II",
    location: "Houston, TX",
    remote: "onsite",
    type: "full_time",
    salary: [75000, 92000],
    summary:
      "Run the servers and virtual infrastructure behind billing, field operations, and emergency systems.",
    duties: [
      "Administer Windows Server and VMware environments",
      "Automate routine tasks in PowerShell",
      "Test backups and disaster-recovery plans",
    ],
    reqs: [
      "Windows Server 3y !",
      "Active Directory 2y",
      "VMware 2y",
      "PowerShell 1y",
      "~Linux",
      "~Disaster Recovery",
    ],
  },
  {
    company: "bayou-region-water",
    title: "Public Data Portal Developer (Contract)",
    location: "Houston, TX",
    remote: "remote",
    type: "contract",
    hourly: [55, 68, 40],
    summary:
      "A six-month contract rebuilding the authority's open-data portal for rainfall and water-quality data.",
    duties: [
      "Build Django pages and APIs over PostgreSQL",
      "Meet WCAG accessibility requirements",
      "Hand off documentation to staff developers",
    ],
    reqs: [
      "Django 2y !",
      "Python 3y",
      "PostgreSQL 2y",
      "~Accessibility",
      "~Docker",
      "~REST APIs",
    ],
  },
  {
    company: "bayou-region-water",
    title: "IT Intern, Field Operations",
    location: "Houston, TX",
    remote: "onsite",
    type: "internship",
    hourly: [18, 21, 40],
    summary:
      "A summer internship supporting the tablets, radios, and networks our field crews rely on.",
    duties: [
      "Set up and repair field tablets and laptops",
      "Help maintain network gear at treatment plants",
      "Track inventory and document fixes",
    ],
    reqs: ["Networking", "Microsoft Excel", "~Windows Server", "~Python"],
  },

  // --- Oyster Creek Devices -----------------------------------------------------------------------------
  {
    company: "oyster-creek-devices",
    title: "Embedded Firmware Engineer",
    location: "Sugar Land, TX",
    remote: "onsite",
    type: "full_time",
    salary: [110000, 135000],
    summary:
      "Write low-power firmware for battery-operated flood and freeze sensors that must last five years.",
    duties: [
      "Develop firmware in C for low-power microcontrollers",
      "Implement Bluetooth LE pairing and updates",
      "Debug hardware on the bench with the electrical team",
    ],
    reqs: [
      "C 3y !",
      "Embedded Systems 3y",
      "Bluetooth Low Energy 2y",
      "~C++",
      "~Internet of Things",
      "~Python",
    ],
  },
  {
    company: "oyster-creek-devices",
    title: "Android Developer",
    location: "Sugar Land, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [100000, 125000],
    summary:
      "Build the Android app customers use to set up sensors and get alerts when water is where it shouldn't be.",
    duties: [
      "Build features in Kotlin and Jetpack Compose",
      "Own Bluetooth device setup flows",
      "Improve app reliability and alert delivery",
    ],
    reqs: [
      "Kotlin 2y !",
      "Android SDK 2y",
      "Jetpack Compose 1y",
      "~Bluetooth Low Energy",
      "~Retrofit",
      "~Firebase",
    ],
  },
  {
    company: "oyster-creek-devices",
    title: "iOS Developer",
    location: "Sugar Land, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [100000, 125000],
    summary:
      "Build the iOS app that pairs with our sensors and sends critical alerts.",
    duties: [
      "Build features in Swift and SwiftUI",
      "Own Bluetooth device setup flows",
      "Write tests and keep releases smooth",
    ],
    reqs: [
      "Swift 2y !",
      "SwiftUI 1y",
      "~UIKit",
      "~Bluetooth Low Energy",
      "~XCTest",
      "~Core Data",
    ],
  },
  {
    company: "oyster-creek-devices",
    title: "QA Test Technician (Part-Time)",
    location: "Sugar Land, TX",
    remote: "onsite",
    type: "part_time",
    hourly: [20, 24, 20],
    summary:
      "Test sensors and apps before each release. Flexible hours for students.",
    duties: [
      "Run manual test plans on devices and apps",
      "File clear bug reports with logs and steps",
      "Help automate repetitive checks",
    ],
    reqs: [
      "Software Testing",
      "Regression Testing",
      "~Python",
      "~Jira",
      "~Bluetooth Low Energy",
    ],
  },

  // --- Woodlands Subsea Robotics -------------------------------------------------------------------------
  {
    company: "woodlands-subsea",
    title: "Robotics Software Engineer",
    location: "The Woodlands, TX",
    remote: "onsite",
    type: "full_time",
    salary: [115000, 140000],
    summary:
      "Write the autonomy software that lets our vehicles inspect pipelines without a tether.",
    duties: [
      "Develop navigation and autonomy in C++ and ROS",
      "Test in our tank and in the Gulf",
      "Analyze mission logs to improve behavior",
    ],
    reqs: [
      "C++ 3y !",
      "ROS 2y !",
      "Python 2y",
      "Linux 2y",
      "~Computer Vision",
      "~Control Systems",
      "~Robotics",
    ],
  },
  {
    company: "woodlands-subsea",
    title: "Computer Vision Engineer",
    location: "The Woodlands, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [125000, 150000],
    summary:
      "Teach our vehicles to spot corrosion, cracks, and marine growth in murky water.",
    duties: [
      "Train detection and segmentation models",
      "Optimize models to run on vehicle GPUs",
      "Build labeling and evaluation tools",
    ],
    reqs: [
      "Computer Vision 3y !",
      "Python 3y",
      "OpenCV 2y",
      "PyTorch 2y",
      "~Object Detection",
      "~CUDA",
      "~Image Segmentation",
    ],
  },
  {
    company: "woodlands-subsea",
    title: "Robotics Intern",
    location: "The Woodlands, TX",
    remote: "onsite",
    type: "internship",
    hourly: [27, 31, 40],
    summary:
      "A summer internship working on real underwater robots with our autonomy team.",
    duties: [
      "Build a tool or feature for our vehicles",
      "Run tests in our water tank",
      "Present results to the engineering team",
    ],
    reqs: ["Python !", "C++", "~ROS", "~Linux", "~Robotics", "~MATLAB"],
  },
  {
    company: "woodlands-subsea",
    title: "DevOps Engineer (Contract)",
    location: "The Woodlands, TX",
    remote: "hybrid",
    type: "contract",
    hourly: [60, 75, 40],
    summary:
      "A six-month contract building CI/CD and cluster tooling for our data-processing platform.",
    duties: [
      "Build GitHub Actions pipelines",
      "Run Kubernetes clusters for mission data processing",
      "Add monitoring and alerting",
    ],
    reqs: [
      "Kubernetes 2y !",
      "Docker 3y",
      "GitHub Actions 2y",
      "Linux 3y",
      "~Terraform",
      "~Prometheus",
    ],
  },

  // --- Katy Prairie Insurance -------------------------------------------------------------------------------
  {
    company: "katy-prairie-insurance",
    title: "Python Developer, Claims Automation",
    location: "Katy, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [95000, 118000],
    summary:
      "Help families get paid faster after storms by automating claims intake and document review.",
    duties: [
      "Build FastAPI services for claims intake",
      "Extract data from claim documents and photos",
      "Work with adjusters to remove manual steps",
    ],
    reqs: [
      "Python 2y !",
      "FastAPI 1y",
      "SQL 2y",
      "~Optical Character Recognition",
      "~Robotic Process Automation",
      "~Docker",
    ],
  },
  {
    company: "katy-prairie-insurance",
    title: "Actuarial Data Analyst",
    location: "Katy, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [78000, 95000],
    summary:
      "Support pricing and reserving with clean data and solid statistics.",
    duties: [
      "Prepare policy and claims data for actuarial models",
      "Analyze loss trends after weather events",
      "Automate recurring reports",
    ],
    reqs: [
      "Statistics 2y !",
      "SQL 1y",
      "R 1y",
      "~Python",
      "~Microsoft Excel",
      "~Tableau",
    ],
  },
  {
    company: "katy-prairie-insurance",
    title: "Customer Platform Developer (.NET)",
    location: "Katy, TX",
    remote: "hybrid",
    type: "full_time",
    salary: [100000, 122000],
    summary: "Build the policyholder portal and the agent tools behind it.",
    duties: [
      "Build C# and .NET services and APIs",
      "Build Angular screens for agents and customers",
      "Move legacy services to Azure",
    ],
    reqs: [
      "C# 2y !",
      ".NET 2y",
      "Microsoft SQL Server 2y",
      "~Angular",
      "~Microsoft Azure",
      "~Entity Framework",
    ],
  },
  {
    company: "katy-prairie-insurance",
    title: "Data Engineering Intern",
    location: "Katy, TX",
    remote: "hybrid",
    type: "internship",
    hourly: [24, 28, 40],
    summary:
      "A summer internship building data pipelines for our claims analytics team.",
    duties: [
      "Build a small ETL pipeline in Python",
      "Write SQL to validate data",
      "Document and demo your pipeline",
    ],
    reqs: ["Python !", "SQL", "~ETL", "~Apache Airflow", "~Git"],
  },

  // --- Barton Springs Analytics (Austin, remote-first) ----------------------------------------------------
  {
    company: "barton-springs-analytics",
    title: "Data Scientist",
    location: "Austin, TX",
    remote: "remote",
    type: "full_time",
    salary: [125000, 155000],
    summary:
      "Build demand-forecasting and pricing models that retailers use to plan inventory.",
    duties: [
      "Build and evaluate forecasting models",
      "Design experiments with customers",
      "Explain results to non-technical stakeholders",
    ],
    reqs: [
      "Python 3y !",
      "Statistics 3y",
      "SQL 2y",
      "Machine Learning 2y",
      "~A/B Testing",
      "~Causal Inference",
      "~dbt",
    ],
  },
  {
    company: "barton-springs-analytics",
    title: "Analytics Engineer",
    location: "Austin, TX",
    remote: "remote",
    type: "full_time",
    salary: [115000, 140000],
    summary:
      "Own the dbt models that turn messy retail data into clean tables for our models and dashboards.",
    duties: [
      "Build and test dbt models in Snowflake",
      "Onboard new customer data sources",
      "Define metrics with the data science team",
    ],
    reqs: [
      "SQL 3y !",
      "dbt 2y !",
      "Snowflake 1y",
      "~Python",
      "~Looker",
      "~Data Modeling",
    ],
  },
  {
    company: "barton-springs-analytics",
    title: "Machine Learning Intern (Remote)",
    location: "Austin, TX",
    remote: "remote",
    type: "internship",
    hourly: [32, 36, 40],
    summary:
      "A remote summer internship on our forecasting team, open to students anywhere in Texas.",
    duties: [
      "Prototype a model improvement",
      "Run experiments and report results",
      "Pair with a data scientist mentor",
    ],
    reqs: [
      "Python !",
      "Machine Learning",
      "~PyTorch",
      "~Pandas",
      "~Natural Language Processing",
    ],
  },

  // --- Alamo Heights Cyber (San Antonio) -------------------------------------------------------------------
  {
    company: "alamo-heights-cyber",
    title: "SOC Analyst I",
    location: "San Antonio, TX",
    remote: "onsite",
    type: "full_time",
    salary: [70000, 85000],
    summary:
      "Defend hospitals and utilities from our 24/7 security operations center.",
    duties: [
      "Monitor and triage alerts for client environments",
      "Investigate incidents and write clear reports",
      "Tune detections with senior analysts",
    ],
    reqs: [
      "Security Operations 1y !",
      "SIEM",
      "Networking 1y",
      "~Splunk",
      "~Linux",
      "~Incident Management",
    ],
  },
  {
    company: "alamo-heights-cyber",
    title: "Penetration Tester",
    location: "San Antonio, TX",
    remote: "remote",
    type: "full_time",
    salary: [115000, 140000],
    summary:
      "Test client web apps, networks, and cloud environments before attackers do.",
    duties: [
      "Run web, network, and cloud penetration tests",
      "Write findings that engineers can act on",
      "Build tooling to speed up testing",
    ],
    reqs: [
      "Penetration Testing 3y !",
      "Burp Suite 2y",
      "Python 2y",
      "~Metasploit",
      "~OWASP",
      "~Kali Linux",
      "~Cloud Security",
    ],
  },
  {
    company: "alamo-heights-cyber",
    title: "Cloud Security Engineer (Contract)",
    location: "Houston, TX",
    remote: "remote",
    type: "contract",
    hourly: [75, 95, 40],
    summary:
      "A six-month contract hardening AWS environments for a Houston healthcare client.",
    duties: [
      "Review and fix IAM and network configurations",
      "Codify guardrails in Terraform",
      "Prepare evidence for a SOC 2 audit",
    ],
    reqs: [
      "Cloud Security 3y !",
      "AWS 3y",
      "Identity and Access Management 2y",
      "~Terraform",
      "~Zero Trust",
      "~SOC 2 Compliance",
    ],
  },
];
