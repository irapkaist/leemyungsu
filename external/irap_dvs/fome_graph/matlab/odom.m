%set constants
K = [199.6530123165822 0 177.43276376280926;
    0 199.6530123165822 126.81215684365904;
    0 0 1];
cameraParams = cameraParameters('IntrinsicMatrix', K);
addpath('/home/jhlee/data/dvs/');
dc = 100;
sc = 0.01;
% event_potential = zeros(346,260);
minnum = 10; %minimum number of features to track
lownum = 125; %add features if features < lownum
feat_2d.idx = [];
feat_2d.num = [];
feat_2d.desc = [];
feat_2d.idepth = [];
feat_2d.cov = [];
feat_2d_old = feat_2d;
gtt = 600;
gaussian = (1/16)*[1 2 1; 2 4 2; 1 2 1];
Rots = {};
Trns = {};
Mtch = {};
feat_2d_list = {};
feat3ds = {};
feat2ds = {};
stats = {};
feat_3d.id = [];
feat_3d.xyz = [];
feat_3d.cov = {};
ba_length = 6;

%brief filter
measure_no = 0;
BRIEF_n = 256;
window_size = 15;
pattern = brief_generator(BRIEF_n,window_size);

dvst = init_dvst;
% dvst = 1;
total = 6354367-init_dvst;
% total = 7000000-init_dvst;
% event_potential = nogauss_1050_400;
% event_potential = nogauss_1050_100;
% event_potential = gauss_1050_500;
% event_potential = gauss_1050_100;
event_potential = gauss_600_100;
% figure(1)
% imagesc(event_potential');
% hold on

initialization = 0;
% imgidx = 0;
% for every events, do the procedure
while (events{1,dvst}.t < gts{1,gtt+800}.t)
% while (dvst < 7000000)
    if (dvst >= length(events))
        break;
    end
    dt = events{1,dvst+1}.t - events{1,dvst}.t;
    x = events{1,dvst}.x + 1;
    y = events{1,dvst}.y + 1;
    p = 2*events{1,dvst}.p - 1;
    event_potential = exp(-dc*dt)*event_potential;
    if (x==1 || x==346 || y==1 || y==260)
        dvst = dvst + 1;
        continue;
    end
    event_potential(x-1:x+1,y-1:y+1) = event_potential(x-1:x+1,y-1:y+1) + p*gaussian;
%     event_potential(x,y) = event_potential(x,y) + p;
    if rem(dvst,5000)==0
        fprintf("time : %.2f%%, feature(tracked): %i\n",100*((dvst-init_dvst)/total),length(feat_2d.idx));
        
%         filename = ['/home/jhlee/imgs/' 'sample' num2str(imgidx) '.png'];
%         imwrite(event_potential',filename);
%         imgidx = imgidx + 1;
%         imagesc(event_potential');
%         drawnow
    end
    
    if (events{1,dvst}.t < gts{1,gtt}.t)
        dvst = dvst + 1;
        continue;
    end
    
    %remove features gathered in same points
    rmvidx = zeros(1,length(feat_2d.idx));
    for rmv = 1:length(feat_2d.idx)
        if (nnz(feat_2d.idx == feat_2d.idx(rmv)) > 1)
            if nnz(rmvidx(feat_2d.idx == feat_2d.idx(rmv))) == 0
                rmvidx(rmv) = 1;
                continue;
            end
            feat_2d.idx(rmv) = 0;
        end
    end
    if (nnz(feat_2d.idx==0) ~= 0)
%         fprintf('removing %i feature(s) by collapse\n', nnz(features.idx==0));
        feat_2d.num = feat_2d.num(feat_2d.idx~=0);
        feat_2d.idx = feat_2d.idx(feat_2d.idx~=0);
        feat_2d.cov = feat_2d.cov(feat_2d.idx~=0);
        feat_2d.desc = feat_2d.desc(feat_2d.idx~=0,:);
        feat_2d.idepth = feat_2d.idepth(feat_2d.idx~=0,:);
    end
    
    
    % if nonsufficient number of features, find more feature to track
    if (length(feat_2d.idx)<lownum)
%         fprintf("adding features, feature size : %i",length(features.idx));
        feat_2d = add_features(feat_2d,event_potential,pattern,lownum,BRIEF_n);
%         fprintf("-> %i\n",length(features.idx));
        if (length(feat_2d.idx)<minnum)
            disp("too few features to track : waiting until new features");
            continue;
        end
    end
    
    if rem(dvst,7500)==0
%         figure(1)
%         imagesc(event_potential');
%         drawnow
%         plotfeatures(feat_2d.idx);
    end
    
    if rem(dvst,7500)==0
        if ~isempty(feat_2d_old.idx)
            num_old = feat_2d_old.num;
            num_new = feat_2d.num;
            dep_old = feat_2d_old.idepth;
            dep_new = feat_2d.idepth;
            [~, match2] = ismember(num_old,num_new);
            [~, match1] = ismember(num_new,num_old);
            idx_old = feat_2d_old.idx;
            idx_new = feat_2d.idx;
            
            idx_old_match = idx_old(match1(match1~=0));
            num_old_match = num_old(match1(match1~=0));
            dep_old_match = dep_old(match1(match1~=0));
            idx_new_match = idx_new(match2(match2~=0));
            num_new_match = num_new(match2(match2~=0));
            dep_new_match = dep_new(match2(match2~=0));
            
            [x_old, y_old] = uvfromidx(idx_old_match,346);
            [x_new, y_new] = uvfromidx(idx_new_match,346);
            
            pts_old = [x_old' y_old' num_old_match' dep_old_match];
            pts_new = [x_new' y_new' num_new_match' dep_new_match];
            if length(x_old)<=6
                dvst = dvst + 1;
                fprintf('nonsufficient matches, skipping track!\n');
                continue;
            end
            if initialization < ba_length+1
                feat_2d = init_triangulate(feat_2d,pts_old,pts_new,cameraParams,sc);
                dvst = dvst + 1;
                feat_2d_old = feat_2d;
                [R, t] = estimate_RT([x_old' y_old' dep_old_match],[x_new' y_new' dep_new_match],cameraParams);
                measure_no = measure_no + 1;
                initialization = initialization + 1;
            else
                measure_no = measure_no + 1;
                [R, t] = estimate_RT([x_old' y_old' dep_old_match],[x_new' y_new' dep_new_match],cameraParams);
                feat_2d = update_2d_features(feat_2d,feat_2d_old,R,t,cameraParams,sc);
            end
%             Rots{measure_no} = R;
%             Trns{measure_no} = t;
%             Mtch{measure_no} = length(idx_old_match);
%             fprintf('tracking occured, matches : %i\n',length(order_p));

            %state and feature update
            if measure_no > 1
                state = stats{measure_no-1};
            else
                state = [0 0 0 0 0 0]; % r p h x y z
            end
            state_new = [state(1:3)'+rot2rph(R); R*state(4:6)'+t]';
            feat_3d = update_3d_features(feat_2d,feat_3d,state_new,cameraParams);
            
            %store states
            stats(measure_no) = {state_new};
            feat3ds(measure_no) = {feat_3d};
            feat2ds(measure_no) = {feat_2d};
            
            if initialization < ba_length+1
                continue;
            else
                if (initialization == ba_length+1)
                    disp("initialization completed, proceed to BA");
                    initialization = initialization +1;
                end
            end
            %Bundle Adjustment
%             if rem(length(stats),ba_length)==0
%                 [feat3ds, stats] = bundleAdj_RT(feat2ds, feat3ds, stats, cameraParams, ba_length);
%             end
        end
        %store variables
        f2 = length(feat_2d_list)+1;
        feat_2d_list{f2}.num = feat_2d.num;
        feat_2d_list{f2}.idx = feat_2d.idx;
        feat_2d_list{f2}.idepth = feat_2d.idepth;
        feat_2d_old = feat_2d;
    end
%     check and track feature point
    if rem(dvst,1000)==0
        feat_2d = track_features_2d(feat_2d,event_potential,pattern,BRIEF_n);
    end
    dvst = dvst + 1;
end

% % plot feature trajectory
% plottrajectory(feat_2d_list);
% figure(1)
% imagesc(event_potential');
% hold on;
% drawnow
% for feat=1:20:length(featlist)
%     plotfeatures(featlist{feat}.idx);
% end

% plot the camera trajectory
figure(2)
hold on
gti = 600;
gt_dt = gts{1,gtt+1}.t - gts{1,gtt}.t;
gt_eul = quat2eul([gts{1,gtt+1}.t_x gts{1,gtt+1}.t_y gts{1,gtt+1}.t_z gts{1,gtt+1}.t_w])...
        - quat2eul([gts{1,gtt}.t_x gts{1,gtt}.t_y gts{1,gtt}.t_z gts{1,gtt}.t_w]);
gt_xyz = [gts{1,gtt+1}.x gts{1,gtt+1}.y gts{1,gtt+1}.z] - [gts{1,gtt}.x gts{1,gtt}.y gts{1,gtt}.z];
for gtt=gti:gti+800
    scatter3(gts{1,gtt}.x,gts{1,gtt}.y,gts{1,gtt}.z,'MarkerEdgeColor','k','MarkerFaceColor',[0 .75 .75]);
end
hold off

figure(3)
hold on
initial_xyz = [gts{1,gti}.x,gts{1,gti}.y,gts{1,gti}.z];
initial_rph = quat2eul([gts{1,gti}.t_x,gts{1,gti}.t_y,gts{1,gti}.t_z,gts{1,gti}.t_w]);
integrated_pose = zeros(length(stats)+1,6);
integrated_pose(1,:) = [initial_rph, initial_xyz];
for a=10:length(stats)-10
    scatter3(integrated_pose(a,4),integrated_pose(a,5),integrated_pose(a,6),...
        'MarkerEdgeColor','k','MarkerFaceColor',[0.75 0 .75]);
    statnow = stats{a};
    integrated_pose(a+1,1:3) = integrated_pose(a,1:3) + statnow(1:3);
    integrated_pose(a+1,4:6) = integrated_pose(a,4:6) + (eul2rotm(integrated_pose(a,1:3))*statnow(4:6)')';
end
hold off
axis equal

% % plot the estimation error
% figure(2)
% gti = 1050;
% relative_gt = zeros(6,100);
% for gtt=gti:gti+99
%     gt_r0 = quat2eul([gts{1,gtt}.t_x,gts{1,gtt}.t_y,gts{1,gtt}.t_z,gts{1,gtt}.t_w]);
%     gt_r1 = quat2eul([gts{1,gtt+1}.t_x,gts{1,gtt+1}.t_y,gts{1,gtt+1}.t_z,gts{1,gtt+1}.t_w]);
%     gt_t0 = [gts{1,gtt}.x gts{1,gtt}.y gts{1,gtt}.z];
%     gt_t1 = [gts{1,gtt+1}.x gts{1,gtt+1}.y gts{1,gtt+1}.z];
%     relative_gt(:,gtt-gti+1) = [gt_r1-gt_r0 gt_t1-gt_t0]';
% end
% a1 = subplot(6,1,1);
% hold(a1,'on')
% plot(relative_gt(1,:));
% a2 = subplot(6,1,2);
% hold(a2,'on')
% plot(relative_gt(2,:));
% a3 = subplot(6,1,3);
% hold(a3,'on')
% plot(relative_gt(3,:));
% a4 = subplot(6,1,4);
% hold(a4,'on')
% plot(relative_gt(4,:));
% a5 = subplot(6,1,5);
% hold(a5,'on')
% plot(relative_gt(5,:));
% a6 = subplot(6,1,6);
% hold(a6,'on')
% plot(relative_gt(6,:));
% 
% relative_est = zeros(6,length(Rots));
% for estt=1:length(Rots)-1
%     relative_est(1:3,estt) = rot2rph(Rots{estt});
%     relative_est(4:6,estt) = [Trns{estt}(1), Trns{estt}(2), Trns{estt}(3)];
% end
% subplot(6,1,1);
% plot(relative_est(1,:));
% subplot(6,1,2);
% plot(relative_est(2,:));
% subplot(6,1,3);
% plot(relative_est(3,:));
% subplot(6,1,4);
% plot(relative_est(4,:));
% subplot(6,1,5);
% plot(relative_est(5,:));
% subplot(6,1,6);
% plot(relative_est(6,:));