function omnicopter_sim()
ITERATION_TIMES = 20000;

math = se3_math;

%%%%%%%%%%%%%%
% Parameters %
%%%%%%%%%%%%%%

%parameters of uav dyanmics
uav_dynamics = dynamics;        %create uav dynamics object
uav_dynamics.dt = 0.001;        %set iteration period [sec]
uav_dynamics.mass = 1;          %set uav mass [kg]
uav_dynamics.a = [0; 0; 0];     %acceleration of uav [m/s^2], effected by applied force
uav_dynamics.v = [0; 0; 0];     %initial velocity of uav [m/s]
uav_dynamics.x = [0; 0; 0];     %initial position of uav [m]
uav_dynamics.W = [0; 0; 0];     %initial angular velocity of uav
uav_dynamics.W_dot = [0; 0; 0]; %angular acceleration of uav, effected by applied moment
uav_dynamics.f = [0; 0; 0];     %force generated by controller
uav_dynamics.M = [0; 0; 0];     %moment generated by controller
uav_dynamics.J = [0.01466 0 0;  %inertia matrix of uav
    0 0.01466 0;
    0 0 0.01466];

%initial attitude (DCM)
init_attitude(1) = deg2rad(0); %roll
init_attitude(2) = deg2rad(0); %pitch
init_attitude(3) = deg2rad(0); %yaw
uav_dynamics.R = math.euler_to_dcm(init_attitude(1), init_attitude(2), init_attitude(3));

%parameters of omnicopter
d = 2; %[m]

propeller_drag_coeff = 6.579e-2;   %[N/(m/s)?]
motor_max_thrust = 900 * 0.00980665; %[gram force] to [N]

%omnicopter control gains
omnicopter_kx = [30; 30; 20];
omnicopter_kv = [20; 20; 20];
omnicopter_kR = [20; 20; 20];
omnicopter_kW = [10; 10; 10];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialization: calculate position and direction vectors %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%position vectors
p1 = [+d; +d; +d];
p2 = [-d; +d; +d];
p3 = [-d; -d; +d];
p4 = [+d; -d; +d];
p5 = [+d; +d; -d];
p6 = [-d; +d; -d];
p7 = [-d; -d; -d];
p8 = [+d; -d; -d];

p1 = math.vector_enu_to_ned(p1);
p2 = math.vector_enu_to_ned(p2);
p3 = math.vector_enu_to_ned(p3);
p4 = math.vector_enu_to_ned(p4);
p5 = math.vector_enu_to_ned(p5);
p6 = math.vector_enu_to_ned(p6);
p7 = math.vector_enu_to_ned(p7);
p8 = math.vector_enu_to_ned(p8);

%direction vectors
r1 = calculate_direction_vector(p1, -pi/4);
r2 = calculate_direction_vector(p2, 3*pi/4);
r3 = calculate_direction_vector(p3, -pi/4);
r4 = calculate_direction_vector(p4, 3*pi/4);
r5 = calculate_direction_vector(p5, -3*pi/4 + pi);
r6 = calculate_direction_vector(p6, pi/4 + pi);
r7 = calculate_direction_vector(p7, -3*pi/4 + pi);
r8 = calculate_direction_vector(p8, pi/4 + pi);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Visualization of position and direction vectors %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%3d plot
figure
xlim([-3, 3]);
ylim([-3, 3]);
zlim([-3, 3]);
xlabel('x')
ylabel('y')
zlabel('z')
daspect([1 1 1])
view(-35,45);
grid on
hold on

%plot position vectors
quiver3(0, 0, 0, p1(1), p1(2), p1(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p2(1), p2(2), p2(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p3(1), p3(2), p3(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p4(1), p4(2), p4(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p5(1), p5(2), p5(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p6(1), p6(2), p6(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p7(1), p7(2), p7(3), 'color', [0 0 1]);
quiver3(0, 0, 0, p8(1), p8(2), p8(3), 'color', [0 0 1]);

%plot direction vectors
quiver3(p1(1), p1(2), p1(3), r1(1), r1(2), r1(3), 'color', [1 0 0]);
quiver3(p2(1), p2(2), p2(3), r2(1), r2(2), r2(3), 'color', [1 0 0]);
quiver3(p3(1), p3(2), p3(3), r3(1), r3(2), r3(3), 'color', [1 0 0]);
quiver3(p4(1), p4(2), p4(3), r4(1), r4(2), r4(3), 'color', [1 0 0]);
quiver3(p5(1), p5(2), p5(3), r5(1), r5(2), r5(3), 'color', [1 0 0]);
quiver3(p6(1), p6(2), p6(3), r6(1), r6(2), r6(3), 'color', [1 0 0]);
quiver3(p7(1), p7(2), p7(3), r7(1), r7(2), r7(3), 'color', [1 0 0]);
quiver3(p8(1), p8(2), p8(3), r8(1), r8(2), r8(3), 'color', [1 0 0]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Construct omnicopter Jacobian matrix %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%spin direction matrix
S = [1, 1, 1, 1, -1, -1, -1, -1;
    1, 1, 1, 1, -1, -1, -1, -1;
    1, 1, 1, 1, -1, -1, -1, -1];

%force Jacobian
Jf = [r1, r2, r3, r4, r5, r6, r7, r8];

%moment Jacobian
Jm_thrust = [cross(p1, r1), ...
    cross(p2, r2), ...
    cross(p3, r3), ...
    cross(p4, r4), ...
    cross(p5, r5), ...
    cross(p6, r6), ...
    cross(p7, r7), ...
    cross(p8, r8)];
Jm_drag = propeller_drag_coeff * S .* Jf;
Jm = Jm_thrust + Jm_drag;

%force/moment Jacobian
J = [Jf; Jm];

disp("force/moment Jacobian:");
disp(J);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Construct matrices and vectors for force/moment optimization QP %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Q = eye(8);
tb = [-motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust;
    -motor_max_thrust];
tu = [motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust;
    motor_max_thrust];

disp('press any key to start simulation.');
pause;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%
% controller setpoints %
%%%%%%%%%%%%%%%%%%%%%%%%
xd = zeros(3, ITERATION_TIMES);
vd = zeros(3, ITERATION_TIMES);
a_d = [0; 0; 0];
yaw_d = zeros(1, ITERATION_TIMES);
Wd = [0; 0; 0];
W_dot_d = [0; 0; 0];

%%%%%%%%%%%%%%%%%%%%%
%   path planning   %
%%%%%%%%%%%%%%%%%%%%%
% cirular motion
radius = 1;         %[m]
circum_rate = 0.25; %[hz], times of finished a circular trajectory per second
yaw_rate = 0.1;    %[hz], times of full rotation around z axis per second
for i = 1: ITERATION_TIMES
    %plan heading
    if i == 1
        yaw_d(1) = 0;
    else
        yaw_d(i) = yaw_d(i - 1) + (yaw_rate * uav_dynamics.dt * 2 * pi);
    end
    if yaw_d(i) > pi %bound yaw angle between +-180 degree
        yaw_d(i) = yaw_d(i) - (2 * pi);
    end
    
    %plan position
    xd(1, i) = radius * cos(circum_rate * uav_dynamics.dt * i * pi);
    xd(2, i) = radius * sin(circum_rate * uav_dynamics.dt * i * pi);
    xd(3, i) = -1;
    
    %plan velocity
    vd(1, i) = radius * -sin(circum_rate * uav_dynamics.dt * i * pi);
    vd(2, i) = radius * cos(circum_rate * uav_dynamics.dt * i * pi);
    vd(3, i) = 0;
end

%%%%%%%%%%%%%%
% plot datas %
%%%%%%%%%%%%%%
time_arr = zeros(1, ITERATION_TIMES);
accel_arr = zeros(3, ITERATION_TIMES);
vel_arr.g = zeros(3, ITERATION_TIMES);
R_arr = zeros(3, 3, ITERATION_TIMES);
euler_arr = zeros(3, ITERATION_TIMES);
pos_arr = zeros(3, ITERATION_TIMES);
W_dot_arr = zeros(3, ITERATION_TIMES);
W_arr = zeros(3, ITERATION_TIMES);
M_arr = zeros(3, ITERATION_TIMES);
prv_angle_arr = zeros(1, ITERATION_TIMES);
eR_prv_arr = zeros(3, ITERATION_TIMES);
eR_arr = zeros(3, ITERATION_TIMES);
eW_arr = zeros(3, ITERATION_TIMES);
ex_arr = zeros(3, ITERATION_TIMES);
ev_arr = zeros(3, ITERATION_TIMES);

%%%%%%%%%%%%%%%%%%%%%
% Control main loop %
%%%%%%%%%%%%%%%%%%%%%
for i = 1: ITERATION_TIMES
    disp(sprintf('%dth iteration', i));
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % Update System Dynamics %
    %%%%%%%%%%%%%%%%%%%%%%%%%%
    uav_dynamics = update(uav_dynamics);
    
    %desired attutide (DCM)
    desired_roll = deg2rad(0);
    desired_pitch = deg2rad(0);
    desired_yaw = yaw_d(i);
    Rd = math.euler_to_dcm(desired_roll, desired_pitch, desired_yaw);
    Rdt = Rd.';
    
    Rt = uav_dynamics.R.';
    I = eye(3);
    
    %attitude errors expressed in principle rotation angle
    eR_prv = 0.5 * trace(I - Rdt*uav_dynamics.R);
    
    %attitude error and attitude rate errors
    eR = 0.5 * math.vee_map_3x3((Rd'*uav_dynamics.R - Rt*Rd));
    eW = uav_dynamics.W - Rt*Rd*Wd;
    
    %calculate feedforward moment
    WJW = cross(uav_dynamics.W, uav_dynamics.J * uav_dynamics.W);
    M_feedfoward = WJW - uav_dynamics.J*(math.hat_map_3x3(uav_dynamics.W)*Rt*Rd*Wd - Rt*Rd*W_dot_d);
    
    %calculate desired moment
    M_d = -omnicopter_kR.*eR -omnicopter_kW.*eW + M_feedfoward;
    
    %position error and velocity error
    ex = uav_dynamics.x - xd(:, i);
    ev = uav_dynamics.v - vd(:, i);
    
    %calculate desired force
    e3 = [0; 0; 1];
    f_d = Rt * -(-omnicopter_kx.*ex -omnicopter_kv.*ev -uav_dynamics.mass*uav_dynamics.g*e3);
    
    %calculate motor thrust via optimization
    options = [];
    options = optimoptions('quadprog','Display','off'); %make quadprog silent
    zeta = [f_d; M_d];
    f_motors = quadprog(Q, [], [], [], J, zeta, tb, tu, [], options);
    
    %convert motor thrusts to rigirbody force/torque
    p_array = [p1, p2, p3, p4, p5, p6, p7, p8];
    r_array = [r1, r2, r3, r4, r5, r6, r7, r8];
    f = omnicopter_thrust_to_force(f_motors, r_array);
    M = omnicopter_thrust_to_moment(f_motors, p_array, r_array, propeller_drag_coeff);
    
    %print desired force and
    s = sprintf('desired force: (%f, %f, %f), feasible force: (%f, %f, %f)', ...
        f_d(1), f_d(2), f_d(3), f(1), f(2), f(3));
    disp(s);
    
    s = sprintf('desired moment: (%f, %f, %f), feasible moment: (%f, %f, %f)', ...
        M_d(1), M_d(2), M_d(3), M(1), M(2), M(3));
    disp(s);
    
    %feed force/torque to the dynamics system
    uav_dynamics.M = M;
    uav_dynamics.f = f;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    % update plot data arrays %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    time_arr(i) = i * uav_dynamics.dt;
    eR_prv_arr(:, i) = rad2deg(eR_prv);
    eR_arr(:, i) = rad2deg(eR);
    eW_arr(:, i) = rad2deg(eW);
    accel_arr(:, i) = uav_dynamics.a;
    vel_arr.g(:, i) = uav_dynamics.v;
    pos_arr(:, i) = uav_dynamics.x;
    R_arr(:, :, i) = uav_dynamics.R;
    euler_arr(:, i) = rad2deg(math.dcm_to_euler(uav_dynamics.R));
    W_dot_arr(:, i) = rad2deg(uav_dynamics.W_dot);
    W_arr(:, i) = rad2deg(uav_dynamics.W);
    M_arr(:, i) = uav_dynamics.M;
    ex_arr(:, i) = ex;
    ev_arr(:, i) = ev;
end

r_array = [r1, r2, r3, r4, r5, r6, r7, r8];
p_array = [p1, p2, p3, p4, p5, p6, p7, p8];

vectors_rigidbody_animation(r_array, p_array, 8, pos_arr, R_arr, 200, ITERATION_TIMES, uav_dynamics.dt)

%%%%%%%%%%%%%%
% plot datas %
%%%%%%%%%%%%%%
%principle rotation error angle
%principle rotation error angle
figure('Name', 'principle rotation error angle');
plot(time_arr, eR_prv_arr(1, :));
title('principle rotation error angle');
xlabel('time [s]');
ylabel('x [deg]');

%attitude error
figure('Name', 'eR');
subplot (3, 1, 1);
plot(time_arr, eR_arr(1, :));
title('eR');
xlabel('time [s]');
ylabel('x [deg]');
subplot (3, 1, 2);
plot(time_arr, eR_arr(2, :));
xlabel('time [s]');
ylabel('y [deg]');
subplot (3, 1, 3);
plot(time_arr, eR_arr(3, :));
xlabel('time [s]');
ylabel('z [deg]');

%attitude rate error
figure('Name', 'eW');
subplot (3, 1, 1);
plot(time_arr, eW_arr(1, :));
title('eW');
xlabel('time [s]');
ylabel('x [deg/s]');
subplot (3, 1, 2);
plot(time_arr, eW_arr(2, :));
xlabel('time [s]');
ylabel('y [deg/s]');
subplot (3, 1, 3);
plot(time_arr, eW_arr(3, :));
xlabel('time [s]');
ylabel('z [deg/s]');

%attitude (euler angles)
figure('Name', 'attitude (euler angles)');
subplot (3, 1, 1);
plot(time_arr, euler_arr(1, :));
title('attitude (euler angles)');
xlabel('time [s]');
ylabel('roll [deg]');
subplot (3, 1, 2);
plot(time_arr, euler_arr(2, :));
xlabel('time [s]');
ylabel('pitch [deg]');
subplot (3, 1, 3);
plot(time_arr, euler_arr(3, :), time_arr, rad2deg(yaw_d));
xlabel('time [s]');
ylabel('yaw [deg]');

%position
figure('Name', 'position (NED frame)');
subplot (3, 1, 1);
plot(time_arr, pos_arr(1, :), time_arr, xd(1, :));
title('position (NED frame)');
xlabel('time [s]');
ylabel('x [m]');
subplot (3, 1, 2);
plot(time_arr, pos_arr(2, :), time_arr, xd(2, :));
xlabel('time [s]');
ylabel('y [m]');
subplot (3, 1, 3);
plot(time_arr, -pos_arr(3, :), time_arr, -xd(3, :));
xlabel('time [s]');
ylabel('-z [m]');

%velocity
figure('Name', 'velocity (NED frame)');
subplot (3, 1, 1);
plot(time_arr, vel_arr.g(1, :), time_arr, vd(1, :));
title('velocity (NED frame)');
xlabel('time [s]');
ylabel('x [m/s]');
subplot (3, 1, 2);
plot(time_arr, vel_arr.g(2, :), time_arr, vd(2, :));
xlabel('time [s]');
ylabel('y [m/s]');
subplot (3, 1, 3);
plot(time_arr, -vel_arr.g(3, :), time_arr, -vd(3, :));
xlabel('time [s]');
ylabel('-z [m/s]');

%acceleration
figure('Name', 'acceleration (NED frame)');
subplot (3, 1, 1);
plot(time_arr, accel_arr(1, :));
title('acceleration (NED frame)');
xlabel('time [s]');
ylabel('x [m/s^2]');
subplot (3, 1, 2);
plot(time_arr, accel_arr(2, :));
xlabel('time [s]');
ylabel('y [m/s^2]');
subplot (3, 1, 3);
plot(time_arr, -accel_arr(3, :));
xlabel('time [s]');
ylabel('-z [m/s^2]');

%position error
figure('Name', 'position error');
subplot (3, 1, 1);
plot(time_arr, ex_arr(1, :));
title('position error');
xlabel('time [s]');
ylabel('x [m]');
subplot (3, 1, 2);
plot(time_arr, ex_arr(2, :));
xlabel('time [s]');
ylabel('y [m]');
subplot (3, 1, 3);
plot(time_arr, ex_arr(3, :));
xlabel('time [s]');
ylabel('z [m]');

%velocity error
figure('Name', 'velocity error');
subplot (3, 1, 1);
plot(time_arr, ev_arr(1, :));
title('velocity error');
xlabel('time [s]');
ylabel('x [m/s]');
subplot (3, 1, 2);
plot(time_arr, ev_arr(2, :));
xlabel('time [s]');
ylabel('y [m/s]');
subplot (3, 1, 3);
plot(time_arr, ev_arr(3, :));
xlabel('time [s]');
ylabel('z [m/s]');

disp('press any key to stop.')
pause;
close all;
end

function vectors_rigidbody_animation(r_array, p_array, motor_cnt, pos_array, R_array, skip_cnt, iteration_times, sleep_time)
figure

for i = 1: skip_cnt: iteration_times
    clf;
    xlim([-7, 7]);
    ylim([-7, 7]);
    zlim([-7, 7]);
    xlabel('x')
    ylabel('y')
    zlabel('z')
    daspect([1 1 1])
    view(-35,45);
    grid on
    hold on
    
    R = R_array(:, :, i);
    
    for j = 1: motor_cnt
        p = [p_array(1, j);
            p_array(2, j);
            p_array(3, j)];
        
        r = [r_array(1, j);
            r_array(2, j);
            r_array(3, j)];
        
        %translation
        pos_x = pos_array(1, i);
        pos_y = pos_array(2, i);
        pos_z = pos_array(3, i);
        
        %rotation
        p = R * p;
        r = R * r;
        
        %plot position vectors
        quiver3(pos_x, pos_y, pos_z, p(1), p(2), p(3), 'color', [0 0 1]);
        
        %plot direction vectors
        quiver3(p(1) + pos_x, p(2) + pos_y, p(3) + pos_z, r(1), r(2), r(3), 'color', [1 0 0]);
    end
    
    pause(sleep_time);
end
end

function r=calculate_direction_vector(p_vec, angle)
math = se3_math;

%base vectors of drone's center
b0_x = [1; 0; 0];
b0_y = [0; 1; 0];
b0_z = [0; 0; 1];

%zero degree direction vector
u_x = p_vec / norm(p_vec);
u_z = cross(u_x, b0_z);
u_y = cross(u_z, u_x);

%normalize
u_x = u_x / norm(u_x);
u_y = u_y / norm(u_y);
u_z = u_z / norm(u_z);

R = math.euler_to_dcm(angle, 0, 0);

r = [u_x, u_y, u_z] * R * [0; 1; 0];
end

function f=omnicopter_thrust_to_force(f_motors, r_array)
f = [0; 0; 0];
for i = 1: 8
    f = f + (f_motors(i) .* r_array(:, i));
end
end

function M=omnicopter_thrust_to_moment(f_motors, p_array, r_array, propeller_drag_coeff)
M = [0; 0; 0];

for i = 1: 8
    M = M + f_motors(i) * cross(p_array(:, i), r_array(:, i)) + ...
        (propeller_drag_coeff .* f_motors(i) .* r_array(:, i));
end
end
