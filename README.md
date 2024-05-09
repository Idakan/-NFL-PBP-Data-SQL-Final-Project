**Guiding question:**

Using NFL play-by-play data, analyze offensive tendencies, explore which offenses are the most successful and why, along with what defenses focus on in order to be successful, with the overall hope of determining offensive and defensive strategies and goals that lead to a high winning percentage. 

Much of my analysis for this project was through constant comparison of various data points. For instance, when evaluating NFL defenses, I compared them in terms of points, yards, turnovers forced and bad plays forced to see which measurement was most useful. With the offense, the key comparison was with passing plays vs running plays, seeing how valuable each one was and how often teams utilized them. In addition, EPA was crucial for me, as I used that statistic to determine what made a play successful and associate a high EPA with a successful offense or offensive player. Perhaps in the future I will find other ways to holistically gauge how good an offense is. As one last point, since the overall goal was to find strategies and ideas that directly lead to winning football games, I experimented with linear regression and R^2 values. While it did not work out the way I would have hoped in problem 2.6, I can use this function to compare other variables and see if I can find something. Below are some of the graphs and queries I was able to make as part of this project.

-	For defense, allowing the fewest points is the most important trait, over field position, time of possession, etc.
-	That being said, the R^2 value is not that high, meaning that we cannot say that the link between allowing fewer points and winning games is very strong
-	Teams with the highest winning percentage, along with the most efficient offenses, tend to pass the ball more often than they throw it
-	Passing plays have far more value (epa per play) than running plays
-	As such it might be easier to have more successful running plays than passing plays, but it is true that for the same number of successful plays, run plays yield a higher win percentage than pass percentage, perhaps a fallacy of some kind
-	Despite this emphasis on passing the ball, the yearly change in passing rate, particularly on first down, is not what we might expect, since it is not strictly positive.

**Useful Visuals:**


![image](https://github.com/Idakan/-NFL-PBP-Data-SQL-Final-Project/assets/20823933/7bd7212b-4986-4527-a2a4-9bc7203ae70a)

![image](https://github.com/Idakan/-NFL-PBP-Data-SQL-Final-Project/assets/20823933/d5171dd2-e69a-450d-887a-559c498e6be2)

![image](https://github.com/Idakan/-NFL-PBP-Data-SQL-Final-Project/assets/20823933/0ddceb1b-459e-4d5a-b4f2-237c85918153)


