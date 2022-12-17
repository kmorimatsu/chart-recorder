REM **************************
REM *                        *
REM * Chart Recorder ver 0.3 *
REM * Constructed by Katsumi *
REM *                        *
REM **************************

REM Reserve data area for 12 hours (43200 secons)
REM dat: data array
REM datstart: data start position
REM datpos: current data position
REM filepos: last saved data position
REM file0time: Time from the power-on of the position dat(0)
REM csvname: file name of CSV file
REM savecontinue: flag to save CSV data every second
REM savepostpone: postpone saving CSV for indicated second(s)
usevar dat,datpos,filepos,file0time,csvname,savecontinue,savepostpone
dim dat(43199)
datpos=-2

REM Create a CSV file for saving data
gosub set_file_name

REM Data acquisition will be done 10 times for calculating average
REM d0: used for fraction corrector event
REM d1: used for UV absorption
REM d2: used for conductivity monitor
usevar d0,d1,d2,adcnum
dim d0(9),d1(9),d2(9)

REM Axes minimum and maximum values
REM xmin,xmax: horizontal axis minimum and maximum values
REM ymin,ymax: left vertical axis (adc1) minimum and maximum values
REM yzmin,yzmax: zoom of ymin and ymax
REM rymin,rymax: right vertical axis (adc2) minimum and maximam values
usevar xmin,xmax,ymin,ymax,yzmin,yzmax,rymin,rymax
xmin=0:xmax=1:ymin=0:ymax=4095:yzmin=0:yzmax=4095:rymin=0:rymax=4095

REM Input from buttons
REM buttons: preserve KEYS(31) data
REM bu: number of up button pressed
REM bd: number of down button pressed
REM bl: number of left button pressed
REM br: number of right button pressed
REM bs: number of start button pressed
usevar buttons,bu,bd,bl,br,bs

REM View controller
REM yzoon: Zoom in vertical axis
REM xzoom: Zoom in horizontal axis
usevar yzoom,xzoom

REM Use timer and intterupt for getting ADC data 30 times in a minute
REM The timer interrupt is used also for counting datpos value
usetimer 33333
interrupt timer,read_adc

REM Previous and current values
usevar d0p,d0c,d1p,d1c,d2p,d2c

REM Initialize min and max values
while datpos<0:idle:wend
gosub store_data
ymin=d1c:ymax=d1c+1
yzmin=ymin:yzmax=ymax
rymin=d2c:rymax=d2c+1

REM Set initial fixed y axes
ymax=3200:yzmax=3200:rem min value is automatic
rymin=250:rymax=1250

REM Start graphyc view
gosub func_keys
gosub clear_console

REM Main loop follows
do
  REM Wait for acquisition in a second
  d=datpos
  while d=datpos:idle:wend
  if 0=in(0) then
    REM Record OFF mode
    datpos=d
    continue
  endif
  if 43200<=datpos then
    REM Reached the end of data.
    REM Delete the beginning 4 hours data 
    REM and move remaining ones reverse.
    REM This process takes about 22 msecs.
    for i=0 to 43199
      dat(i)=dat(i+14400)
    next
    datpos=datpos-14400
    if 14400<=filepos then filepos=filepos-14400
    file0time=file0time+14400
  endif
  
  REM Store data from dat()
  gosub store_data
  
  REM Change view by buttons
  xmax=datpos-1
  gosub zoom
  
  REM Refresh view 
  gosub redraw_axes
  gosub redraw_lines
  
  REM Save data to a file
  if savepostpone then
    savepostpone=savepostpone-1
    if savepostpone<5 then
      gprint 33*8,29*8,1,6," save "
    else
      gprint 33*8,29*8,7,4," save "
    endif
  else
    if datpos%10=1 and filepos+10<=datpos then
      gosub save_data
    elseif savecontinue then
      gosub save_data
    endif
  endif
loop

REM Set the CSV file name
label set_file_name
  var i
  setdir "\\"
  for i=1 to 999
    csvname$="CHART"
    if i<10 then csvname$=csvname$+"0"
    if i<100 then csvname$=csvname$+"0"
    csvname$=csvname$+dec$(i)+".CSV"
    fclose
    if 0=fopen(csvname$,"r") then break
  next
  if 1000<=i then
    print "Disk full."
    end
  endif
  fclose
  fopen csvname$,"w"
  fprint "time,absorption,conductivity,event"
  fclose
  print "Save CSV file as '";csvname$;"'"
return

REM Save data to a CSV file
label save_data
  var a
  a=adcnum
  do
    if 0=fopen(csvname$,"a") then break
    if 0=fputc(0x20) then break
    fseek fseek()-1
    gprint 33*8,29*8,6,2," save "
    do while filepos<datpos-1
      fprint file0time+filepos;",";
      fprint (dat(filepos)>>12) and 4095;",";
      fprint dat(filepos) and 4095;",";
      fprint (dat(filepos)>>24) and 255
      filepos=filepos+1
      if 27<adcnum then
        savecontinue=1
        break
      else
        savecontinue=0
      endif
    loop
    break
  loop
  fclose
  if adcnum<28 and adcnum<a+2 then
    while adcnum<a+2:wend
  endif
  gprint 33*8,29*8,1,5," save "
return

REM Zoom effect routine
REM Also handle "SAVE" button
REM Change the xmin, ymin, and ymax here
label zoom
  yzoom=yzoom+bu
  yzoom=yzoom-bd
  xzoom=xzoom+br
  xzoom=xzoom-bl
  if xzoom<0 then xzoom=0
  if yzoom<0 then yzoom=0
  if 0<br or 0<bl then
    xmin=xmax-(xmax>>xzoom)-1
    if xmin<0 then xmin=0
  endif
  if 0<yzoom then
    if 0<bu or 0<bd then
      yzmin=d1c-((d1c-ymin)>>yzoom)
      yzmax=d1c+((ymax-d1c)>>yzoom)+1
    endif
  else
    yzmin=ymin:yzmax=ymax
  endif
  if 0<bs then savepostpone=30
  bu=0:bd=0:br=0:bl=0:bs=0
return

REM Store data to d0c, d1c, and d2c
label store_data
  d0c=0:for i=0 to 9:d0c=d0c+d0(i):next:d0c=d0c/160
  d1c=0:for i=0 to 9:d1c=d1c+d1(i):next:d1c=d1c/10
  d2c=0:for i=0 to 9:d2c=d2c+d2(i):next:d2c=d2c/10
  dat(datpos)=(d0c<<24)or(d1c<<12)or(d2c)
  if d1c<ymin then ymin=d1c
  if d2c<rymin then rymin=d2c
  if ymax<d1c then ymax=d1c
  if rymax<d2c then rymax=d2c
return

REM Redraw chart lines
label redraw_lines
  REM i: counter
  REM j: temporary integer
  REM k: temporary integer
  REM l: temporary integer
  REM x: horizontal axis pitch x 1024
  REM y: vertical axis pich x 1024
  REM e: end point of rough data
  var i,j,k,l,x,y,e
  boxfill 40,8,280,208,7
  REM Draw ADC2 data (red)
  y=(200<<10)/(rymax-rymin)
  point 40,208-((y*((dat(xmin) and 4095)-rymin))>>10)
  for x=1 to 240
    line ,40+x,208-((y*((dat(xmin+x*(xmax-xmin)/240) and 4095)-rymin))>>10),2
  next
  REM Draw ADC0 data (green)
  if xmax-xmin<240 then
    y=(200<<10)/256
    point 40,208-((y*(((dat(xmin)>>24) and 255)-0))>>10)
    for x=1 to 240
      line ,40+x,208-((y*(((dat(xmin+x*(xmax-xmin)/240)>>24) and 255)-0))>>10),4
    next
  else
    y=(200<<10)/256
    i=xmin
    for x=0 to 240
      j=255 :REM min
      k=0   :REM max
      e=xmin+x*(xmax-xmin)/240
      do while i<=e
        l=(dat(i)>>24) and 255
        if l<j then j=l
        if k<l then k=l
        i=i+1
      loop
      i=e
      line 40+x,208-((y*j)>>10),40+x,208-((y*k)>>10),4
    next
  endif
  REM Draw ADC1 data (black)
  y=(200<<10)/(yzmax-yzmin)
  if ymin=yzmin and ymax=yzmax then
    REM no zooming
    if 240<xmax-xmin then
      point 280,208-((y*(((dat(xmax)>>12) and 4095)-yzmin))>>10)
      e=240*(xmax-100-xmin)/(xmax-xmin)
      for i=0 to 100
        x=240*(xmax-i-xmin)/(xmax-xmin)
        line ,40+x,208-((y*(((dat(xmax-i)>>12) and 4095)-yzmin))>>10),0
      next
    else
      point 280,208-((y*(((dat(xmax)>>12) and 4095)-yzmin))>>10) 
      e=239
    endif
    for x=e to 0 step -1
      line ,40+x,208-((y*(((dat(xmin+x*(xmax-xmin)/240)>>12) and 4095)-yzmin))>>10),0
    next
  else
    REM zooming
    if 240<xmax-xmin then
      j=208-((y*(((dat(xmax)>>12) and 4095)-yzmin))>>10)
      if j<8 then j=8
      if 208<j then j=208
      point 280,j
      e=240*(xmax-100-xmin)/(xmax-xmin)
      for i=0 to 100
        x=240*(xmax-i-xmin)/(xmax-xmin)
        j=208-((y*(((dat(xmax-i)>>12) and 4095)-yzmin))>>10)
        if j<8 then j=8
        if 208<j then j=208
        line ,40+x,j,0
      next
    else
      j=208-((y*(((dat(xmax)>>12) and 4095)-yzmin))>>10)
      if j<8 then j=8
      if 208<j then j=208
      point 280,j 
      e=239
    endif
    for x=e to 0 step -1
      j=208-((y*(((dat(xmin+x*(xmax-xmin)/240)>>12) and 4095)-yzmin))>>10)
      if j<8 then j=8
      if 208<j then j=208
      line ,40+x,j,0
    next
  endif
return

REM Read from ADCs
REM Note that this function is called by interruption
label read_adc
  var i
  REM read from ADC
  i=adcnum%3
  if 0=i then
    d0(adcnum/3)=analog(0)
  elseif 1=i then
    d1(adcnum/3)=analog(1)
  else
    d2(adcnum/3)=analog(2)
  endif
  REM count up number
  adcnum=adcnum+1
  if 29<adcnum then
    adcnum=0
    datpos=datpos+1
  endif
  REM Check buttons
  if buttons then
    buttons=keys(31)
  else
    buttons=keys(31)
    if 0=buttons then
    elseif buttons and 1 then
      bu=bu+1
    elseif buttons and 2 then
      bd=bd+1
    elseif buttons and 4 then
      bl=bl+1
    elseif buttons and 8 then
      br=br+1
    else
      bs=bs+1
    endif
  endif
return

REM Clear graph console for drawing lines
label clear_console
  REM Fill the graph area
  boxfill 0,0,319,223,7
  REM Draw a box and marks
  line 36,4,283,4,1
  line ,283,211,1
  line ,36,211,1
  line ,36,4,1
  line 32,8,36,8,0
  line 32,207,36,207,0
  line 283,8,287,8,2
  line 283,207,287,207,2
  line 40,211,40,215,1
  line 100,211,100,215,1
  line 160,211,160,215,1
  line 220,211,220,215,1
  line 280,211,280,215,1
  REM Draw axes values
  gosub redraw_axes
return

label redraw_axes
  var v
  boxfill 0,4,31,11,7
  boxfill 0,104,31,111,7
  boxfill 0,204,31,211,7
  boxfill 288,4,319,11,7
  boxfill 288,104,319,111,7
  boxfill 288,204,319,211,7
  boxfill 12,216,307,223,7
  gprint gosub(dec_space,yzmax),4,0,7,dec$(yzmax)
  gprint gosub(dec_space,d1c),104,0,7,dec$(d1c)
  gprint gosub(dec_space,yzmin),204,0,7,dec$(yzmin)
  gprint 288,4,2,7,dec$(rymax)
  gprint 288,104,2,7,dec$(d2c)
  gprint 288,204,2,7,dec$(rymin)
  v=xmin
  gprint 20+gosub(dec_center,v),216,1,7,dec$(v+file0time)
  v=(xmin*3+xmax)/4
  gprint 80+gosub(dec_center,v),216,1,7,dec$(v+file0time)
  v=(xmin+xmax)/2
  gprint 140+gosub(dec_center,v),216,1,7,dec$(v+file0time)
  v=(xmin+xmax*3)/4
  gprint 200+gosub(dec_center,v),216,1,7,dec$(v+file0time)
  v=xmax
  gprint 260+gosub(dec_center,v),216,1,7,dec$(v+file0time)
return

REM Show function keys indicator at bottom
label func_keys
  cls
  REM Draw function keys
  gprint  1*8,29*8,1,5," Y \x1e "
  gprint  7*8,29*8,1,5," Y \x1f "
  gprint 13*8,29*8,1,5," X \x1d "
  gprint 19*8,29*8,1,5," X \x1c "
  gprint 26*8,29*8,1,5," mark "
  gprint 33*8,29*8,1,5," save "
  REM Draw CSV file name
  gprint 15*8,28*8,6,0,csvname$
return

label dec_space
  if args(1)<10 then return 24
  if args(1)<100 then return 16
  if args(1)<1000 then return 8
  return 0

label dec_center
  if args(1)<10 then return 16
  if args(1)<100 then return 12
  if args(1)<1000 then return 8
  if args(1)<10000 then return 4
  return 0 
