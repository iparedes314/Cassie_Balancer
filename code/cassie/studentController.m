function tau = studentController(t, s, model, params)
    % Modify this code to calculate the joint torques
    % t - time
    % s - 20x1 state of the robot
    % model - struct containing robot properties
    % params - user defined parameters in studentParams.m
    % tau - 10x1 vector of joint torques

    global control
    
    % State vector components ID
    q = s(1 : model.n);
    dq = s(model.n+1 : 2*model.n);
    x0 = getInitialState(model);
    q0 = x0(1:model.n);

    %% Pick control

    switch control
        case 'zero'
            % [Control #1] zero control
            tau = zeros(10,1);

        case 'highGain'
            % [Control #2] High Gain Joint PD control on all actuated joints
            kp = 500;
            kd = 100;
            x0 = getInitialState(model);
            q0 = x0(1:model.n);
            tau = -kp*(q(model.actuated_idx)-q0(model.actuated_idx)) - kd*dq(model.actuated_idx);

            % Check ground contact
            [leftFront, leftRear, rightFront, rightRear] = computeFootPositions(q, model);
            contact = sum([leftFront(3), leftRear(3), rightFront(3), rightRear(3)] <= 0.01);
            if contact >= 3
                control = 'force';
            end
            
        case 'PD'
            % [Control #3] High Gain Joint PD with individual gains
            % Cannot use
            kp = [1e3;      % abduction
                  1e3;
                  500;      % rotation
                  500;
                  800;      % flexion
                  800;
                  1e5;      % knee
                  1e5;
                  8e2;      % toe
                  8e2];

            kd = [100;      % abduction
                  100;
                  100;      % rotation
                  100;
                  100;      % flexion
                  100;
                  400;      % knee
                  400;
                  200;      % toe
                  200];

            x0 = getInitialState(model);
            q0 = x0(1:model.n);
            qErr = q(model.actuated_idx)-q0(model.actuated_idx);
            dqErr = dq(model.actuated_idx);
            tau = -kp.*qErr - kd.*dqErr;
            
            
        case 'force'
            % FORCE control
            
            % Grasp/Contact Map
            % toe order
            [leftFront, leftRear, rightFront, rightRear] = computeFootPositions(q, model);
            
            CoM = q(1:3);
            rleftFront = rHat(leftFront - CoM);
            rleftRear = rHat(leftRear - CoM);
            rrightFront = rHat(rightFront - CoM);
            rrightRear = rHat(rightRear - CoM);
                        
            Gc = {[eye(3); rleftFront], [eye(3); rleftRear], [eye(3); rrightFront], [eye(3); rrightRear]};

              
            % Only contact points
            contact = ([leftFront(3), leftRear(3), rightFront(3), rightRear(3)]<0.01);
            if sum(contact) == 0
                tau = zeros(10,1);
            else
                Gc = cell2mat(Gc(contact));


                % Pseudoinverse of grasp map
    %             pseGc = (Gc')/(Gc*Gc');
                pseGc = pinv(Gc);

                % Wrench
                Fga = wrench_genPD(q, dq, q0);

                % Contact force
                fc = pseGc*Fga; 
                fc = reshape(fc, [3, sum(contact)]);   % each contact force as column vectors 

                % Distribute forces (points not in contact are zero)
                all_fc = zeros(3,4);
                all_fc(:,contact) = fc;

                fc_lf = all_fc(:,1);
                fc_lb = all_fc(:,2);
                fc_rf = all_fc(:,3);
                fc_rb = all_fc(:,4);

                % Jacobian
                [Jlf, Jlb, Jrf, Jrb] = computeFootJacobians(q, dq, model);
                Jlf = Jlf(4:end, 7:16)';
                Jlb = Jlb(4:end, 7:16)';
                Jrf = Jrf(4:end, 7:16)';
                Jrb = Jrb(4:end, 7:16)';

                tau_des = Jlf*fc_lf + Jlb*fc_lb + Jrf*fc_rf + Jrb*fc_rb;

                tau = -tau_des;
            end
            

           
        otherwise
            warning('Control not recognized.')
    end



