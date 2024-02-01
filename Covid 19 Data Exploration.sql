/*
COVID 19 Data Exploration

Skills used: Joins, CTE's, Temp Tables, Windows Function, Aggregate Functions, Creating Views, Converting Data Types, Case Statements

*/

Select * 
From CovidDeaths
Where continent is not null 
Order By 3,4;


-- Select Data that we are going to be starting with  

Select location, date, total_cases, new_cases, total_deaths, population
From CovidDeaths
Where continent is not null 
Order By 1,2;


-- Total Cases vs. Total Deaths 
-- Shows likelihood of dying if you contract covid in your country

Select location, date, total_cases, total_deaths, 
(CAST(total_deaths AS bigint) / CAST(total_cases AS bigint))*100 AS DeathPercentage
From CovidDeaths
Where location like '%states%'
and continent is not null 
Order By 1,2;


-- Total Cases vs. Population
-- Shows what percentage of population is infected with Covid

Select location, date, population, total_cases, 
(CAST(total_cases AS FLOAT) / CAST(population AS FLOAT))*100 AS PercentPopulationInfected
From CovidDeaths
Where location like '%states%'
and continent is not null 
Order By 1,2;


-- Countries with Highest Infection Rate compared to Population

Select location, population, MAX(total_cases) as HighestInfectionCount, 
MAX((CAST(total_cases AS FLOAT) / CAST(population AS FLOAT)))*100 AS PercentPopulationInfected
From CovidDeaths
Where continent is not null 
--Where location like '%states%'
Group by location, population
Order By PercentPopulationInfected DESC;


-- Countries with Highest Death Count per Population

Select location, MAX(cast(total_deaths as int)) as TotalDeathCount
From CovidDeaths
Where continent is not null 
--Where location like '%states%'
Group by location
Order By TotalDeathCount DESC;



-- BREAKING THINGS DOWN BY CONTINENT 



-- Showing continents with the highest death count per population

Select continent, MAX(cast(total_deaths as int)) as TotalDeathCount
From CovidDeaths
--Where location like '%states%'
Where continent is not null 
Group by continent
Order By TotalDeathCount DESC;


-- GLOBAL NUMBERS

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(new_deaths)/SUM(new_cases)*100 AS DeathPercentage
From CovidDeaths
--Where location like '%states%'
Where continent is not null 
--group by date
Order By 1,2;


-- Total Population vs. Vaccinations
-- Shows Percentage of Population that has received at least one Covid Vaccine 

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as bigint)) OVER (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--,(RollingPeopleVaccinated/population)*100
From CovidDeaths as dea
Join CovidVaccinations as vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is not null
order by 2, 3;


-- Using CTE to perform Calculation on Partition By in previous query 

WITH PopvsVac (continent, location, date, population, new_vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as bigint)) OVER (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--(RollingPeopleVaccinated/population)*100
From CovidDeaths as dea
Join CovidVaccinations as vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is not null
--order by 2, 3
)
Select *, (RollingPeopleVaccinated/population)*100
From PopvsVac


-- Using Temp Table to perform Calculation on Partition By in previous query

DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(Continent nvarchar(255), 
Location nvarchar(255),
Date datetime,
Population numeric, 
New_vaccinations numeric, 
RollingPeopleVaccinated numeric)

INSERT INTO #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as bigint)) OVER (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--(RollingPeopleVaccinated/population)*100
From CovidDeaths as dea
Join CovidVaccinations as vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is not null
--order by 2, 3

Select *, (RollingPeopleVaccinated/population)*100
From #PercentPopulationVaccinated


-- Creating View to store data for later visualizations 

CREATE VIEW PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations as bigint)) OVER (partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--(RollingPeopleVaccinated/population)*100
From CovidDeaths as dea
Join CovidVaccinations as vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is not null

Select *
From PercentPopulationVaccinated


-- Vaccination Progress Analysis
-- Calculate the percentage of the population vaccinated over time

Select vac.location, vac.date, vac.people_vaccinated, dea.population,
    (vac.people_vaccinated / dea.population) * 100 AS PercentPopulationVaccinated
From CovidVaccinations as vac
JOIN CovidDeaths dea ON vac.location = dea.location AND vac.date = dea.date
Where vac.people_vaccinated IS NOT NULL
Order By vac.location, vac.date;


-- Identify countries or regions with high and low vaccination coverage

WITH VaccinationProgress AS (
Select vac.location, vac.date, vac.people_vaccinated, dea.population,
    (vac.people_vaccinated / dea.population) * 100 AS PercentPopulationVaccinated
From CovidVaccinations vac
JOIN CovidDeaths dea ON vac.location = dea.location AND vac.date = dea.date
Where vac.people_vaccinated IS NOT NULL)

Select location,
    MAX(PercentPopulationVaccinated) AS MaxVaccinationCoverage,
    MIN(PercentPopulationVaccinated) AS MinVaccinationCoverage
From VaccinationProgress
Group By location;


-- Median Age vs. Total Deaths Per Location
-- Looking to see if there is a correlation between age and number of deaths

Select Distinct dea.location, vac.median_age,
SUM(cast(dea.total_deaths as bigint)) OVER(PARTITION BY dea.location) AS TotalDeathsPerLocation
From CovidDeaths as dea
JOIN CovidVaccinations as vac 
	ON dea.location = vac.location and dea.date = vac.date 
Where dea.location is not null
Order by median_age;

-- Group Median Ages into bucket ranges, then add Total Deaths up and see which age group has the most deaths 

WITH DeathsData AS (
Select Distinct dea.location, vac.median_age,
SUM(cast(dea.total_deaths as bigint)) OVER(PARTITION BY dea.location) AS TotalDeathsPerLocation
From CovidDeaths as dea
JOIN CovidVaccinations as vac 
	ON dea.location = vac.location and dea.date = vac.date 
Where dea.location is not null),
AgeBuckets AS (
Select median_age,
CASE
    WHEN median_age BETWEEN 15 AND 25.9 THEN 'Median Ages 15 - 25 '
    WHEN median_age BETWEEN 26 AND 35.9 THEN 'Median Ages 26 - 35 '
    WHEN median_age BETWEEN 36 AND 45.9 THEN 'Median Ages 36 - 45 '
    WHEN median_age BETWEEN 46 AND 55.9 THEN 'Median Ages 46 - 48 '
    ELSE 'Other'
END as AgeBucket
From DeathsData)
SELECT DISTINCT AgeBucket,
    SUM(DeathsData.TotalDeathsPerLocation) OVER (PARTITION BY AgeBuckets.AgeBucket) AS TotalDeathsPerAgeBucket
FROM DeathsData
JOIN AgeBuckets ON DeathsData.median_age = AgeBuckets.median_age
ORDER BY AgeBucket;