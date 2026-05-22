# TrackingExplorer
Explore your tracking data interactively. No coding needed. Using R.


# Contact
This tool was developed by Clara Vinyeta Cortada. Please contact me (clara.vinyetacortada@wur.nl ; claravinyetacortada@gmail.com) if you have issues, suggestions or ideas.

# Goal
Once upon a time there was a LOT of data from animal localizations, extracted with Radio tracking technologies (in my case, Radio tags from Cellular Tracking Technologies);
exploring data with R requires manually filtering data (e.g. when you only want to see one bird's data), and coding every change in the map can be time-consuming. Plus, replotting after each filtering can be tedious.
Enter the TrackingExplorer that helps you interactively plot your raw data points without having to worry about coding.

# Technicalities
I used Claude and Perplexity to develop this tool; it is not perfect and will be optimized. Who;s the author of this? Nobody and everybody. Be aware that AI was used to develop this tool, and take the summary statistics with a kilogram of salt. Don't use this tool for analyses. Only to explore your data & get general summaries, please. 

# Data format (IMPORTANT)
for this to work, your data should have a .csv file with:
- one row per localization per individual
- latitude and longitude columns --> projected in the crs 4326 (use "st_transform(4326)%>%").
- identifier --> I call it "bird_band", you can call it something else (but not sure if it will be supported).
- time --> format such as: "2025-11-20 14:41:00" . Not sure if it works with other formats, you can give it a try.
- other categorical variables --> you can have extra columns with a categorical variable (e.g. sex). You can choose to plot those too. Continuous variables here not supported.

# How to use the Tracking Explorer:
1. Download the following documents you'll find in this github page. SAVE THEM ALL IN THE SAME FOLDER:
   - index.html
   - start.R
   - api.R
   - test.csv --> test data, you can use yours directly too.
     
2. **Initialize Start**:
   Set working directory where the files were saved. Open the script "start.R" in... you guessed it, R. Run it. You'll see a window from the api pop up. Leave it open, but you don't need to do anything with it.
   
3. **Initialize html**:
   now double-click on the "index.html" file that you saved earlier. A window should pop up.

4. Load data:
   On the top-left corner, click "load file" and select your data (or the test.csv). Column names may be automatically detected for you. Once loaded, you should be seeing the points plotted.

** Refresh to apply filters ** 
------- you're set, the rest is playing around with the settings. Here are some details: -------

# Description of functions

5. Remap columns:
   click this button from the top-left corner if you want to choose different columns for the lat, lon, id, time or category. For example, I can choose "sex" as the categorical variable, here called  "colour field".
   
6. Date Range: Select start & end date of plotted data. Click 'Refresh' on top-right corner to apply changes.
7. Animals: select or unselect boxes of animals you want to plot. Click 'Refresh'on top-right corner to apply changes.  	

8. Radius: select size of points.

9. Opacity: select opacity of points.

10. Colour mode: allows you to select which factor is used as colours. If you choose time, it will be a continuous gradietn from purplish-orange. "By category"will plot the color by the categorical variable you selected in step 5, during the "colour field" selection.

11. Colour_by: ignore this.

12. Show tracks: you can show tracks that unite points in time. Useful if you e.g. want to make sense of a pattern of movement.

13. Track opacity: self explanatory. How opaque will your track lines be? Up to you.

14. Fade time: the coolest addition. Make your points fade as time goes by (kind of like the fading time in gganimate). Note; this will make your plot go slower.

15. The Slider: You can see an animation of your points through time. Use the slider to go back (slide towards left) or forth (slide rightwards) in time. Play or Pause the animation using the left button. You'll see a timestamp. You can also control the speed of the animation. Have fun playing with that.
    
16. Statistics: be cautious with these descriptive statistics produced from each identifier group (e.g. each bird). I have no clue how they were calculated, it is a black box. Do not use these numbers for any analyses. You can download a csv with the summary statistics, but again, be careful!


----the end :) -----
