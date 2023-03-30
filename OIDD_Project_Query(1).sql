-- Part 0:

-- Putting together the dataset (for context, I merged years 2001-2010, 2012, 2014, 2016, 2018-2021 separately in Excel)
-- From there, I used UNION commands to merge the 2011, 2013, 2015, 2017 tables as seen below

drop table if exists nfl_pbp_copy
    go 
    select * into nfl_pbp_copy 
    from (
        select play_id, [desc], game_id, game_date, week, posteam, posteam_type, defteam, game_seconds_remaining, yards_gained,
               play_type, away_score, home_score, result, 
               passer_player_me, receiver_player_me, rusher_player_me, score_differential, wpa, epa, down
          from nfl_pbp_data

    UNION

        select play_id, [desc], game_id, game_date, week, posteam, posteam_type, defteam, game_seconds_remaining, yards_gained,
               play_type, away_score, home_score, result, 
               passer_player_me, receiver_player_me, rusher_player_me, score_differential, wpa, epa, down 
        from play_by_play_2011

    UNION

        select play_id, [desc], game_id, game_date, week, posteam, posteam_type, defteam, game_seconds_remaining, yards_gained,
               play_type, away_score, home_score, result, 
               passer_player_me, receiver_player_me, rusher_player_me, score_differential, wpa, epa, down
        from play_by_play_2013

    UNION

        select play_id, [desc], game_id, game_date, week, posteam, posteam_type, defteam, game_seconds_remaining, yards_gained,
               play_type, away_score, home_score, result, 
               passer_player_me, receiver_player_me, rusher_player_me, score_differential, wpa, epa, down
        from play_by_play_2015

    UNION

        select play_id, [desc], game_id, game_date, week, posteam, posteam_type, defteam, game_seconds_remaining, yards_gained,
               play_type, away_score, home_score, result, 
               passer_player_me, receiver_player_me, rusher_player_me, score_differential, wpa, epa, down

from play_by_play_2017) as x


-- Let's add some relevant columns.

/*
If needed:

alter table nfl_pbp_copy
drop column season
GO

alter table nfl_pbp_copy
drop column winner
GO
*/
alter table nfl_pbp_copy
add season int NULL
GO

alter table nfl_pbp_copy
add winner NVARCHAR(5) NULL
GO



-- What season the play in question takes place in
update nfl_pbp_copy
set season = 
    (case when month(game_date) <= 2 then year(game_date) - 1 else year(game_date) end)
GO

-- whether the team on offense wound up winning the game
update nfl_pbp_copy
set winner = 
    (case when posteam_type = 'away' 
        then 
            (case when result < 0 then 'Yes' 
                  when result > 0 then 'No' else 'Tied' 
            end) 
        else 
            (case when result > 0 then 'Yes' 
                  when result < 0 then 'No' else 'Tied' 
            end) 
    end)
GO


-- Part 1: fairly basic inquiries

-- 1.1) how many pass plays and run plays logged?
select count(*) from nfl_pbp_copy
where play_type in ('pass','run')

-- 1.2) WPA stands for win probability added, and plays with a large WPA are often very momentous and interesting. Find the top 10 plays by most WPA since 2010, but 
-- exclude field goals and punts. Provide the team, season, and description; you might recognize some of these plays
select top 10 posteam, season, [desc], wpa
from nfl_pbp_copy
where season >= 2010 and play_type not in ('field_goal', 'punt')
order by wpa desc
-- Notice quite a few miracle touchdown plays


-- 1.3) Determine who the best QBs, RBs and WRs are by EPA per play (within a season). You might notice something strange if you do not place thresholds.
-- Best QBs, WRs and RBs 
select top 20 passer_player_me, season, avg(epa) as 'EPA per play' from nfl_pbp_copy
where passer_player_me is not null and play_type = 'pass' and week <= 17 
group by passer_player_me, season
-- Actual QBs
having count(*) > 200
order by sum(epa)* 1.0 / count(*) desc


select top 20 receiver_player_me, season, avg(epa) as 'EPA per play' from nfl_pbp_copy
where receiver_player_me is not null
group by receiver_player_me, season
-- No one trick ponies
having count(*) > 75
order by sum(epa)* 1.0 / count(*) desc

select top 20 rusher_player_me, season, avg(epa) as 'EPA per play' from nfl_pbp_copy
where rusher_player_me is not null and week <= 17
group by rusher_player_me, season
-- removes QBs for the most part
having count(*) > 200
order by avg(epa) desc
-- epa per play is much larger for passing plays than running plays. Interesting...


-- Part 2: DE-FENSE

/*

Obviously defense is a big part of the game, but what is the most important thing a defense does? Give up very few yards? Give up very few points?
Force turnovers? Force a lot of negative plays? Let's try and find out

*/

-- First, let's evaluate turnovers. For this we'll have to search the desc attribute for words such as "intercept" and "fumble". Rank defenses using the RANK() Over
-- function. Note that the defense might not have recovered the fumble
-- Next, focus on the average number of plays for no gain or negative gain, meaning incompletions, tackles for loss, sacks and so on. Rank defenses like before
-- Third, focus on how many points the team gave up over the course of the game (we can use home_score or away_score but you must keep in mind what type of team posteam is)
-- Finally, focus on which teams gave up the fewest yards per play.
-- Assuming that these four factors have the same weight, combine all of them to form a total ranking that will determine which defense is the best defense

-- The query below does all of these steps (2.1 to 2.5)
select defteam, season, 
rank() over (order by sum(case when [desc] LIKE '%INTERCEPTED%' or [desc] LIKE '%FUMBLE%' then 1.0 else 0.0 end) / count(*) desc) as 'Turnover Rank',
rank() over (order by sum(case when [desc] like '%incomplete%' or yards_gained <= 0 and defteam is not null and play_type in ('pass','run')  then 1.0 else 0.0 end) / count(*) desc) as 'Dead Play Rank',
rank() over (order by sum(case when posteam_type = 'home' then home_score else away_score end)*1.0 / count(*)) as 'Scoring Rank',
rank() over (order by sum(yards_gained) * 1.0 / count(*)) as 'Yards Allowed Rank',
rank() over(order by (sum(case when [desc] LIKE '%INTERCEPTED%' or [desc] LIKE '%FUMBLE%' then 1.0 else 0.0 end) / count(*) ) +
                     (sum(case when [desc] like '%incomplete%' or yards_gained <= 0 and defteam is not null and play_type in ('pass','run')  then 1.0 else 0.0 end) / count(*) ) +
                      sum(case when posteam_type = 'home' then home_score else away_score end)*1.0 / count(*) +
                      sum(yards_gained) * 1.0 / count(*))  as '(Averaged) Total Defense Rank'
from nfl_pbp_copy
where play_type in ('run','pass') and week <= 17
group by defteam, season
order by [(Averaged) Total Defense Rank] 

-- 2.6) Judging by the table, scoring rank seems to line up very nicely with total rank. Let's explore the relationship between having a good scoring defense
-- and winning football games, and see what we find


-- On average how many points per game a team gives up
drop table if exists #pointsallowed
create table [#pointsallowed]([Team] [nvarchar](5) NULL, [Season] [smallint] NOT NULL, [Points Allowed] [float] NOT NULL)
insert into #pointsallowed
select distinct defteam, season, sum(case when posteam_type = 'home' then home_score else away_score end)*1.0 / count(*) as 'Points Allowed'
from (select distinct defteam, season, week, play_type, winner, posteam_type, home_score, away_score
from nfl_pbp_copy
where defteam is not NULL and week <= 17 and play_type in ('pass','run')) as x
group by defteam, season
order by [Points Allowed] ASC
select * from #pointsallowed

-- Defensive win percentage (recall how we set up the winner column based on the offensive team)
drop table if exists #winpercentdefense
create table [#winpercentdefense]([Team] [nvarchar](5) NULL, [Season] [smallint] NOT NULL, [Win Percentage] [float] NOT NULL)
insert into #winpercentdefense
select distinct defteam, season, sum(case when winner = 'Yes' then 0 else 1 end) * 1.0 / COUNT(winner) as 'Win Percentage'
from (select distinct defteam, season, week, winner
from nfl_pbp_copy
where defteam is not NULL and week <= 17) as x
group by defteam, season
order by [Win Percentage] desc
select * from #winpercentdefense

-- Join these tables:
drop table if exists #combineddefensetable
select * into #combineddefensetable from
(select w.Team, w.Season, p.[Points Allowed], w.[Win Percentage] 
from #winpercentdefense as w
join #pointsallowed as p on (w.Season = p.Season and w.Team = p.Team)) 
as x


-- Paste this table in Excel, make a scatter plot with Win % on the x-axis and Points allowed on the y-axis.
-- Include the trendline which shows the slope, y-intercept and R^2 value, which is around 0.42

/*
2.7)
Actually on second thought, Excel is for chumps. We can find all that data right here. Make a function that takes in as input our table data and outputs the R^2 value,
showing the relationship between winning percentage and points allowed. Of course, in theory we could use this function for any two columns of numbers, which would be
useful.

Some advice: 
- you need to create a user-defined table type; SQL functions don't accept variables of type TABLE as a parameter
- make the function in steps; make sure you get the correct B1 value, then B0, then TSS, then RSS, and then finally R^2
- obviously you can double check with Excel to make sure you are on the right track


*/

-- first make a user-defined table type that has the same columns as our table from above
create type datatable as TABLE
(
    Team nvarchar(50),
    Season int,
    [Points Allowed] float,
    [Win Percentage] float
)


-- now we make our function
drop function if exists R2
go
create function R2(@data datatable readonly)
Returns FLOAT
BEGIN
    Declare @RSS FLOAT
    set @RSS = 0.0
    Declare @Tss float
    set @Tss = 0.0
    Declare @b1 FLOAT
    declare @b1num FLOAT
    set @b1num = 0.0
    declare @b1denom FLOAT
    set @b1denom = 0.0
    Declare @b0 float
    declare @i int
    declare @j int
    declare @scoreval FLOAT
    declare @winval FLOAT
    declare @avgpoints FLOAT
    select @avgpoints = avg([Points Allowed]) from @data
    declare @avgwin float
    select @avgwin = avg([Win Percentage]) from @data
    set @i = 1
    set @j = 1
    declare @iterations int
    select @iterations = count(*) from @data
    while @i <= @iterations
        BEGIN
        SELECT @winval = [Win Percentage], @scoreval = [Points Allowed] FROM (
            SELECT ROW_NUMBER() OVER (order by [Points Allowed] asc) AS rownumber, *
            FROM @data) AS x
            WHERE rownumber = @i
            set @b1num += (@winval - @avgwin) * (@scoreval - @avgpoints)
            set @b1denom += (@winval - @avgwin) * (@winval - @avgwin)
            set @tss += (@scoreval - @avgpoints) * (@scoreval - @avgpoints)
            set @i += 1
        END
    set @b1 = @b1num / @b1denom
    set @b0 = @avgpoints - @b1 * @avgwin
    while @j <= @iterations
        BEGIN
        SELECT @winval = [Win Percentage], @scoreval = [Points Allowed] FROM (
            SELECT ROW_NUMBER() OVER (order by [Points Allowed] asc) AS rownumber, *
            FROM @data) AS x
            WHERE rownumber = @j
            set @rss += (@scoreval - (@b1 * @winval +  @b0)) * (@scoreval - (@b1 * @winval + @b0))
            set @j += 1
        END
    return 1 - (@rss/@tss)
END
GO

-- make our variable that we will plug into the function
declare @defensedatatable as datatable
declare @j INT
set @j = 1
declare @teamval NVARCHAR(10)
declare @seasonval INT
declare @scoreval FLOAT
declare @winval float
declare @iterations int
select @iterations = count(*) from #combineddefensetable

-- put in our data from the temp table into the variable
while @j <= @iterations
    BEGIN
    SELECT @winval = [Win Percentage], @scoreval = [Points Allowed], @teamval = Team, @seasonval = Season FROM (
            SELECT ROW_NUMBER() OVER (order by [Points Allowed] asc) AS rownumber, *
            FROM #combineddefensetable) AS x
            WHERE rownumber = @j
            insert into @defensedatatable (Team, Season, [Points Allowed], [Win Percentage]) values (@teamval, @seasonval, @scoreval, @winval)
            set @j += 1
    END
declare @r2 FLOAT

-- now we can find r^2
set @r2 = dbo.R2(@defensedatatable)
print(@r2)
-- Good job! Unfortunately our r^2 value is lower than we would like. But still, it was worth looking into. And now we can use this function to test various
-- relationships.


/*

Part 3: Offense

*/

-- 3.1) Let's find out, which teams averaged the most Points per Drive, and which averaged the fewest.

-- Points
drop table if exists #points
create table [#points]([Team] [nvarchar](5) NULL, [Season] [smallint] NOT NULL, [Points] [int] NOT NULL)
insert into #points 
select distinct posteam, season, sum(case when posteam_type = 'away' then away_score else home_score end) as 'Number of Points scored' 
from (select distinct posteam, posteam_type, away_score, home_score, season, week
from nfl_pbp_copy
where posteam is not NULL and week <= 17) as x 
group by posteam, season

--- Drives
drop table if exists #drives
create table [#drives]([Team] [nvarchar](5) NULL, [Season] [smallint] NOT NULL, [Number of Drives] [int] NOT NULL)
insert into #drives 
select distinct x.posteam, x.season, count(*) as 'Number of Drives'
from(select distinct posteam, season, week, drive from nfl_pbp_data
where posteam is not null and week <= 17) as X
group by posteam, season

-- Combine the tables and determine PPD
select top 20 p.team, d.season, p.points, d.[Number of Drives], cast(round(p.points * 1.0 / d.[Number of Drives],3) as float) as 'Points Per Drive' 
from #points as p join #drives as d on p.team = d.team and p.season = d.season
order by p.points * 1.0 / d.[Number of Drives] desc
-- Some teams averaged more than a field goal per drive!


select top 20 p.team, d.season, p.points, d.[Number of Drives], cast(round(p.points * 1.0 / d.[Number of Drives],3) as float) as 'Points Per Drive' 
from #points as p join #drives as d on p.team = d.team and p.season = d.season
order by p.points * 1.0 / d.[Number of Drives] asc
-- Some teams did not even average a whole point per drive


-- 3.2) Now, let's try and determine some relationship between playcalling and winning


-- 2a) Every team's win percentage

drop table if exists #winpercent
create table [#winpercent]([Team] [nvarchar](5) NOT NULL, [Season] [smallint] NOT NULL, [Win Percentage] [float] NOT NULL,
                    Constraint pk Primary Key (Team, Season))
insert into #winpercent 
select distinct posteam, season, sum(case when winner = 'Yes' then 1 else 0 end) * 1.0 / COUNT(winner) as 'Winning Rate'
from (select distinct posteam, season, week, winner
from nfl_pbp_copy
where posteam is not NULL and week <= 17) as x
group by posteam, season

-- 2b) Every team's play-choice percentages (in meaningful situations)
drop table if exists #pcp
create table [#pcp]([Team] [nvarchar](5) NOT NULL, [Season] [smallint] NOT NULL, [Pass Percentage] [float] NOT NULL, [Run Percentage] [float] NOT NULL,
                    Constraint pk2 Primary Key (Team, Season))
insert into #pcp 
select distinct posteam, season, sum(case when play_type = 'pass' then 1 else 0 end) * 1.0 / COUNT(play_type) as 'Pass Rate',
sum(case when play_type = 'run' then 1 else 0 end) * 1.0 / COUNT(play_type) as 'Run Rate'
from(select posteam, season, play_type, week
from nfl_pbp_copy
where posteam is not NULL and score_differential between -10 and 10 and game_seconds_remaining > 450 and week <= 17) as x
where play_type in ('run','pass')
group by posteam, season

-- 2c) Join the tables together
select p.[Team], p.[Season], w.[Win Percentage], p.[Pass Percentage], p.[Run Percentage] 
from #pcp as p
join #winpercent as w on p.Team = w.Team and p.Season = w.Season
order by [Win Percentage] desc
-- Looks like successful teams love throwing the ball


-- 3.3) Can we establish a benchmark on how many successful plays a team needs to have in a season to be successful? Let's find out!

/*

How can we gauge what makes a play "successful?" Let's go back to utilizing EPA. Suppose we define a successful play as a run or pass that yields
more than twice as much EPA as the average play (for run plays and pass plays respectively)

*/

-- Start by finding the average epa for a pass play and for a run play
declare @avgepapass float
declare @avgeparun float
declare @epapass float
declare @eparun float
select @avgeparun = sum(case when play_type = 'run' then epa else 0 end)/ sum(case when play_type = 'run' then 1.0 else 0 end), 
       @avgepapass = sum(case when play_type = 'pass' then epa else 0 end)/ sum(case when play_type = 'pass' then 1.0 else 0 end)
from nfl_pbp_copy
where epa is not NULL

-- Now we can determine how many successful plays we had
select posteam as 'Team', season, sum(case when epa > 2 * @avgeparun and play_type = 'run' then 1 else 0 end) as 'Number of Successful Run Plays',
sum(case when epa > 2* @avgepapass and play_type = 'pass' then 1 else 0 end) as 'Number of Successful Pass Plays',
sum(case when epa > 2 * @avgeparun and play_type = 'run' then 1 else 0 end) +
sum(case when epa > 2 * @avgepapass and play_type = 'pass' then 1 else 0 end) as 'Number of Successful Plays Total'
from nfl_pbp_copy
where week <= 17 and posteam is not null
group by posteam, season
order by [Number of Successful Plays Total] desc

-- Merge this information with our win percentage table from before
drop table if exists successful_play_data
select * into successful_play_data
from (
select posteam as 'Team', season, sum(case when epa > 2 * @avgeparun and play_type = 'run' then 1 else 0 end) as 'Number of Successful Run Plays',
sum(case when epa > 2* @avgepapass and play_type = 'pass' then 1 else 0 end) as 'Number of Successful Pass Plays',
sum(case when epa > 2 * @avgeparun and play_type = 'run' then 1 else 0 end) +
sum(case when epa > 2 * @avgepapass and play_type = 'pass' then 1 else 0 end) as 'Number of Successful Plays Total'
from nfl_pbp_copy
where week <= 17 and posteam is not null
group by posteam, season) as x


declare @i INT
declare @WINPERCENTPASS FLOAT
declare @WINPERCENTRUN FLOAT
declare @WINPERCENTTOTAL FLOAT

set @i = 51

while @i<=576
    BEGIN
        select @WINPERCENTPASS = avg([Win Percentage]) from (
            select s.Team, s.season, w.[Win Percentage], s.[Number of Successful Run Plays], s.[Number of Successful Pass Plays], s.[Number of Successful Plays Total] 
            from successful_play_data as s
            join #winpercent as w on w.Season = s.season and w.Team = s.team) as x
            where [Number of successful pass plays] between @i and (@i + 25)

        select @WINPERCENTRUN = AVG([Win Percentage]) 
        from (select s.Team, s.season, w.[Win Percentage], s.[Number of Successful Run Plays], s.[Number of Successful Pass Plays], s.[Number of Successful Plays Total] 
              from successful_play_data as s
              join #winpercent as w on w.Season = s.season and w.Team = s.team) as X
              where [Number of Successful Run Plays] between @i and @i + 25
        

        select @WINPERCENTTOTAL = AVG([Win Percentage]) 
        from (select s.Team, s.season, w.[Win Percentage], s.[Number of Successful Run Plays], s.[Number of Successful Pass Plays], s.[Number of Successful Plays Total] 
              from successful_play_data as s
              join #winpercent as w on w.Season = s.season and w.Team = s.team) as X
              where [Number of Successful Plays Total] between @i and @i + 25
        
        print('When a team has between ' + ltrim(str(@i)) + ' and ' + ltrim(str(@i + 25)) + ' successful run plays in a season, their winning percentage is ' + ltrim(str(@WINPERCENTRUN, 10, 3)) + '.')
        print('When a team has between ' + ltrim(str(@i)) + ' and ' + ltrim(str(@i + 25)) + ' successful pass plays in a season, their winning percentage is ' + ltrim(str(@WINPERCENTPASS, 10, 3)) + '.')
        print('When a team has between ' + ltrim(str(@i)) + ' and ' + ltrim(str(@i + 25)) + ' successful plays total in a season, their winning percentage is ' + ltrim(str(@WINPERCENTTOTAL, 10, 3)) + '.')
        set @i=@i+25
        -- Line Break
        print(char(10))
END

-- Huh? It seems that successful running plays contribute to winning more than successful passing plays? Why is that? 
-- Maybe because running EPA is much lower than passing EPA? Because of the game situation?
-- Also, it seems like between 476 and 501 successful plays is where we break the 0.600 barrier, making your playoff chances almost a certainty. Interesting.

-- Teams that win love passing, so league-wide have teams begun passing it more and more? 
-- 3.4) Write a CTE and determine, on a year-by-year basis, how much the rate of passing on first down has changed over time.
GO
with passing_plays (Passing_Plays, Season)
AS
(select count(*) as [Long Passing Plays], season as [Season] from nfl_pbp_copy
where week <= 17 and down = 1
group by season)
select str(t2.season) + ' to ' + ltrim(str(t1.season)) as Interval, 100* (log(t1.[Passing_Plays])-log(t2.[Passing_Plays])) as PercentChange
from passing_plays as t1
join passing_plays as t2 ON t1.season = t2.season+1
order by t1.season DESC
GO

-- Meh; fairly boring results. Do the same thing but analyze how often teams go for it on 4th down (3.5)

GO
with fourth_downs (Fourth_Downs, Season)
AS
(select count(*) as [# of Fourth Down Attempts], season as [Season] from nfl_pbp_copy
where play_type in ('pass','run') and week <= 17 and down = 4
group by season)
select str(t2.season) + ' to ' + ltrim(str(t1.season)) as Interval, 100* (log(t1.[Fourth_Downs])-log(t2.[Fourth_Downs])) as PercentChange
from fourth_downs as t1
join fourth_downs as t2 ON t1.season = t2.season+1
order by t1.season DESC
GO
-- Now that's more interesting

-- One last thing to do

-- Using EPA once more, let's try to address a key question. Typically the first 15 or so plays (almost all in the first quarter) are scripted, while 
-- plays in the fourth quarter come solely from adjustments based on how the game has gone. 
-- Is there a significant difference in play calls, success, yards gained or lost, for great offenses that is? (3.6)

-- To answer this question, find the average epa/play in each quarter to see when good teams perform the best

select top 15 posteam as 'Team', season, 
sum(case when game_seconds_remaining >= 2700 then epa else 0 end) / sum(case when play_type in ('pass','run') and game_seconds_remaining >= 2700 then 1 else 0 end) as 'First Quarter/Scripted Plays Success',
sum(case when game_seconds_remaining >= 1800 and game_seconds_remaining <= 2700 then epa else 0 end)/ sum(case when play_type in ('pass','run') and game_seconds_remaining <= 2700 and game_seconds_remaining >= 1800 then 1 else 0 end) as 'Second Quarter Success',
sum(case when game_seconds_remaining >= 900 and game_seconds_remaining <= 1800 then epa else 0 end)/ sum(case when play_type in ('pass','run') and game_seconds_remaining <= 1800  and game_seconds_remaining >= 900 then 1 else 0 end) as 'Third Quarter Success',
sum(case when game_seconds_remaining <= 900 then epa else 0 end)/ sum(case when play_type in ('pass','run') and game_seconds_remaining <= 900 then 1 else 0 end) as 'Fourth Quarter/OT Success' 
from nfl_pbp_copy
where play_type in ('pass','run') and score_differential between -10 and 10
group by posteam, season
order by avg(epa) desc

-- Interesting. Results seem to be very mixed. Some teams like the 2007 Patriots were dominant in the 1st and 4th quarters; the Chiefs recently have been amazing
-- in the second quarter, and overall these teams are consistently good (with one notable exception, the 2016 Falcons had a negative EPA in the 4th quarter...)

-- That is all!