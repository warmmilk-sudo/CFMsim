clc;clear
pathname = '../data2/';

%% parameters set manual
theta = 15/180*pi; %deflection angle(radian)
line_density = 2;  %1-high density;2-middle density;4-low density
scale = 23.1;      %the upper limit velocity (cm/s) 
Reverse = 1;       %1-left deflection;0-right deflection 
%velocity and modulus threshold
Velocity_thre_high = 2.96843;    
Velocity_thre_low = 0.0742109;
Modulus_thre_high = 8000;        
Modulus_thre_mid = 5000;  
Modulus_thre_low = 200;
%wall filter coefficient
maxOrder = 6;       
WFOrder = 5;
WFOrder_inc = [2,2,2;
               2,0,0;
               2,2,2];
%frame average coefficient
R0_AvgWeight = 0.2; 
R1_AvgWeight = 0.2;
R1_AvgCoef = 0;
% R0 threshold
R0_thre = 25;    

FenceRemove = 1;   %if remove fence line
FR_thre = 32;      %flash reject threshold
%% 
load cfm_colormap.mat
cfm_clrmap=cfm_clrmap0./256;
if (Reverse==1)
    cfm_clrmap = flipud(cfm_clrmap);
end

if (FenceRemove==1)
    ens_start = 2;
else
    ens_start = 1;
end

WF_LowLow = min(WFOrder+WFOrder_inc(3,1),maxOrder);
WF_LowMid = min(WFOrder+WFOrder_inc(3,2),maxOrder);
WF_LowHigh = min(WFOrder+WFOrder_inc(3,3),maxOrder);
WF_MidLow = min(WFOrder+WFOrder_inc(2,1),maxOrder);
WF_MidMid = min(WFOrder+WFOrder_inc(2,2),maxOrder);
WF_MidHigh = min(WFOrder+WFOrder_inc(2,3),maxOrder);
WF_HighLow = min(WFOrder+WFOrder_inc(1,1),maxOrder);
WF_HighMid = min(WFOrder+WFOrder_inc(1,2),maxOrder);
WF_HighHigh = min(WFOrder+WFOrder_inc(1,3),maxOrder);
NoFilter = 255;

for frm_idx=1:9
    filename = ['c_linedata',num2str(frm_idx+1),'.mat'];
    load ([pathname filename]);
    [sampleCnt,lineCnt,enssembleNum] = size(frmI);
%% PreEstimate
     %remove DC
     SumI = zeros(sampleCnt,lineCnt);
     SumQ = zeros(sampleCnt,lineCnt);
     for idx=ens_start:enssembleNum
         SumI = SumI + frmI(:,:,idx);
         SumQ = SumQ + frmQ(:,:,idx);
     end
     SumI = SumI./(enssembleNum-ens_start+1);
     SumQ = SumQ./(enssembleNum-ens_start+1);
     for idx = 1:enssembleNum
         frmI_rmvDC(:,:,idx) = frmI(:,:,idx)-SumI;
         frmQ_rmvDC(:,:,idx) = frmQ(:,:,idx)-SumQ;
     end
     %Calculate Modulus value and velocity pre-estimate value
    Modulus = zeros(sampleCnt,lineCnt);
    for idx=ens_start:enssembleNum
        Modulus = Modulus + (frmI_rmvDC(:,:,idx).^2+frmQ_rmvDC(:,:,idx).^2);
    end
    PreEst_re = zeros(sampleCnt,lineCnt);
    PreEst_im = zeros(sampleCnt,lineCnt);
    for idx=ens_start:enssembleNum-1
        PreEst_re =  PreEst_re + frmI_rmvDC(:,:,idx) .* frmI_rmvDC(:,:,idx+1) + frmQ_rmvDC(:,:,idx) .* frmQ_rmvDC(:,:,idx+1);
        PreEst_im =  PreEst_im + frmI_rmvDC(:,:,idx) .* frmQ_rmvDC(:,:,idx+1) - frmQ_rmvDC(:,:,idx) .* frmI_rmvDC(:,:,idx+1);
    end
    v_PreEst = abs(atan2(PreEst_im,PreEst_re));
    %Wall Filter order chosen
    WF_Index = zeros(sampleCnt,lineCnt); 
    POWHigh = Modulus_thre_high^2*(enssembleNum-ens_start+1);
    POWMid = Modulus_thre_mid^2*(enssembleNum-ens_start+1);
    POWLow = Modulus_thre_low^2*(enssembleNum-ens_start+1);
    for j=1:lineCnt
        for i=1:sampleCnt
            if (v_PreEst(i,j)<Velocity_thre_low)
                if(Modulus(i,j)<POWLow)
                    WF_Index(i,j) = WF_LowLow;
                else
                    if(Modulus(i,j)<POWMid)
                        WF_Index(i,j) = WF_MidLow;
                    else
                        if (Modulus(i,j)<POWHigh)
                            WF_Index(i,j) = WF_HighLow;
                        else
                            WF_Index(i,j) = NoFilter;
                        end
                    end
                end
            else
                if(v_PreEst(i,j)<Velocity_thre_high)
                    if(Modulus(i,j)<POWLow)
                        WF_Index(i,j) = WF_LowMid;
                    else
                        if(Modulus(i,j)<POWMid)
                            WF_Index(i,j) = WF_MidMid;
                        else
                            if (Modulus(i,j)<POWHigh)
                                WF_Index(i,j) = WF_HighMid;
                            else
                                WF_Index(i,j) = NoFilter;
                            end
                        end
                    end
                else
                     if(Modulus(i,j)<POWLow)
                        WF_Index(i,j) = WF_LowHigh;
                        else
                            if(Modulus(i,j)<POWMid)
                                WF_Index(i,j) = WF_MidHigh;
                            else
                                if (Modulus(i,j)<POWHigh)
                                    WF_Index(i,j) = WF_HighHigh;
                                else
                                    WF_Index(i,j) = NoFilter;
                                end
                            end
                     end
                end
            end
        end
    end
                           
%% Polynomial WallFilter 
%     x=reshape(1:enssembleNum,1,1,enssembleNum);
%     frmI_filtered = zeros(sampleCnt, lineCnt, enssembleNum);
%     frmQ_filtered = zeros(sampleCnt, lineCnt, enssembleNum);
%     for j=1:lineCnt
%         for i=1:sampleCnt
%             n = WF_Index(i,j);
%             if (n~=NoFilter)
%                 p = polyfit(x,frmI(i,j,:),n);
%                 fI = polyval(p,x,n);
%                 frmI_filtered(i,j,:) =  frmI(i,j,:) - fI;
% 
%                 p = polyfit(x,frmQ(i,j,:),n);
%                 fQ = polyval(p,x,n);
%                 frmQ_filtered(i,j,:) =  frmQ(i,j,:) - fQ;
%             end
%         end
%     end
%     save ([pathname 'tempdata',num2str(frm_idx),'.mat'], 'frmI_filtered', 'frmQ_filtered')
    
    load ([pathname 'tempdata',num2str(frm_idx),'.mat'])

%% Calculate R0,R1, with average frame
    R0 = zeros(sampleCnt,lineCnt);
    for idx=ens_start:enssembleNum
        R0 = R0 + sqrt(frmI_filtered(:,:,idx) .^2 + frmQ_filtered(:,:,idx) .^2);
    end
    R0 = R0./(enssembleNum-ens_start+1);
    R1_re = zeros(sampleCnt,lineCnt);
    R1_im = zeros(sampleCnt,lineCnt);
     for idx=ens_start:enssembleNum-1
         R1_re = R1_re + frmI_filtered(:,:,idx) .* frmI_filtered(:,:,idx+1) + frmQ_filtered(:,:,idx) .* frmQ_filtered(:,:,idx+1);
         R1_im = R1_im + frmI_filtered(:,:,idx) .* frmQ_filtered(:,:,idx+1) - frmQ_filtered(:,:,idx) .* frmI_filtered(:,:,idx+1);
     end
     
    if (frm_idx>1)
        R0 = (1-R0_AvgWeight).*R0 + R0_AvgWeight.*R0_pre;
        R1_re = (1-R1_AvgWeight).*R1_re + R1_AvgWeight.*R1_re_pre;
        R1_im = (1-R1_AvgWeight).*R1_im + R1_AvgWeight.*R1_im_pre;
    end
    
    R0_pre = R0;
    R1_re_pre = R1_re;
    R1_im_pre = R1_im;
%% Normalized to 8bit(-128 ~ +127)
    velocity = zeros(sampleCnt,lineCnt);
    t = R0>R0_thre;
    velocity(t) = atan2(R1_im(t),R1_re(t)).*127/pi;
    velocity(velocity>127) = 127;
    velocity(velocity<-128) = -128;
    velocity_frms(:,:,frm_idx) = int8(round(velocity(:,1:lineCnt)));
%% FlashReject
    velocity_8bit = FlashReject_UIS( velocity_frms, frm_idx, FR_thre);
%% smooth
    velocity_8bit = medfilt2(velocity_8bit,[3,3]);
    
%% scan conversion
    deci = 8;
    dx = 38.4/256*line_density; %%mm
    dz = 1540/64/2/1000*deci;   %%mm
    for i=1:sampleCnt
        CoordXsrt = floor((sampleCnt-i)*sin(theta)*dz/dx);
        for j=1:lineCnt
            velocity_8bitSC(i,j+CoordXsrt) = velocity_8bit(i,j);
        end
    end
%% display images
    figure(2);
    image((1:lineCnt+floor(sampleCnt*sin(theta)*dz/dx)).*dx,(1:sampleCnt).*dz,double(velocity_8bitSC)+128);
    axis equal;axis tight
    colormap(cfm_clrmap)
    colorbar('Ticks',[1,255],...
         'TickLabels',{['-',num2str(scale),' cm/s'],['+',num2str(scale),' cm/s']})
     pause(0.1)
end     
        