module VHelper::CloudManager
  class VHelperCloud
    CLOUD_WORK_CREATE = 'create cluster'
    CLOUD_WORK_DELETE = 'delete cluster'
    CLOUD_WORK_LIST   = 'list cluster'
    CLOUD_WORK_START  = 'start'
    CLOUD_WORK_STOP   = 'stop'
    CLOUD_WORK_NONE   = 'none'

    CLUSTER_BIRTH       = "birth"
    CLUSTER_CONNECT     = "connectting"
    CLUSTER_FETCH_INFO  = "fetching"
    CLUSTER_UPDATE      = "updating"
    CLUSTER_TEMPLATE_PLACE = "tempalte placing"
    CLUSTER_PLACE       = "placing"
    CLUSTER_DEPLOY      = "deploying"
    CLUSTER_RE_FETCH_INFO = "refetching"
    CLUSTER_WAIT_START  = "waiting start"
    CLUSTER_DELETE    = "deleting"
    CLUSTER_DONE      = "done"
    CLUSTER_START     = 'starting'
    CLUSTER_STOP      = 'stop'

    CLUSTER_CREATE_PROCESS = {
        CLUSTER_BIRTH           =>[0,1],
        CLUSTER_CONNECT         =>[1,4],
        CLUSTER_FETCH_INFO      =>[5,5],
        CLUSTER_TEMPLATE_PLACE  =>[10,5],
        CLUSTER_PLACE           =>[15,5],
        CLUSTER_UPDATE          =>[20,5],
        CLUSTER_DEPLOY          =>[25,60],
        CLUSTER_RE_FETCH_INFO   =>[25,60],
        CLUSTER_WAIT_START      =>[85,20],
        CLUSTER_DONE            =>[100,0],
    }

    CLUSTER_DELETE_PROCESS = {
      CLUSTER_BIRTH       => [0, 1],
      CLUSTER_CONNECT     => [1, 4],
      CLUSTER_FETCH_INFO  => [5,5],
      CLUSTER_DELETE      => [10, 90],
      CLUSTER_DONE        => [100, 0],
    }

    CLUSTER_LIST_PROCESS = {
      CLUSTER_BIRTH       => [0, 1],
      CLUSTER_CONNECT     => [1, 4],
      CLUSTER_FETCH_INFO  => [5,95],
      CLUSTER_DONE        => [100, 0],
    }

    CLUSTER_START_PROCESS = {
      CLUSTER_BIRTH       => [0, 1],
      CLUSTER_CONNECT     => [1, 4],
      CLUSTER_FETCH_INFO  => [5, 25],
      CLUSTER_START       => [30,70],
      CLUSTER_DONE        => [100,0],
    }

    CLUSTER_STOP_PROCESS = {
      CLUSTER_BIRTH       => [0, 1],
      CLUSTER_CONNECT     => [1, 4],
      CLUSTER_FETCH_INFO  => [5, 25],
      CLUSTER_STOP        => [30,70],
      CLUSTER_DONE        => [100,0],
    }

    CLUSTER_PROCESS = {
      CLOUD_WORK_CREATE => CLUSTER_CREATE_PROCESS,
      CLOUD_WORK_DELETE => CLUSTER_DELETE_PROCESS,
      CLOUD_WORK_LIST   => CLUSTER_LIST_PROCESS,
      CLOUD_WORK_START  => CLUSTER_START_PROCESS,
      CLOUD_WORK_STOP   => CLUSTER_STOP_PROCESS,
    }

    def get_result_by_vms(servers, vms, options={})
      vms.each_value { |vm|
        result = get_from_vm_name(vm.name)
        next if result.nil?
        vm.cluster_name = @cluster_name #vhelper_cluster_name
        vm.group_name = result[2]
        vm.created = options[:created]
        servers << vm
      }
    end

    def get_result
      result = IaasResult.new
      @vm_lock.synchronize {
        result.waiting = @preparing_vms.size
        result.deploy = @deploy_vms.size
        result.waiting_start = @existed_vms.size
        result.success = @finished_vms.size
        result.failure = @failure_vms.size + @placement_failed
        result.succeed = @success && result.failure <= 0
        result.running = result.deploy + result.waiting + result.waiting_start
        result.total = result.running + result.success + result.failure
        result.servers = []
        get_result_by_vms(result.servers, @deploy_vms, :created => false) 
        get_result_by_vms(result.servers, @existed_vms, :created => true)
        get_result_by_vms(result.servers, @failure_vms, :created => false)
        get_result_by_vms(result.servers, @finished_vms, :created => true)
      }
      result
    end

    def get_progress
      progress = IaasProcess.new
      progress.cluster_name = @cluster_name
      progress.result = get_result
      progress.status = @status
      progress.finished = @finished
      progress.progress = 0
      case @action
      when CLOUD_WORK_CREATE,CLOUD_WORK_DELETE, CLOUD_WORK_LIST, CLOUD_WORK_START, CLOUD_WORK_STOP
        prog = CLUSTER_PROCESS[@action]
        progress.progress = prog[@status][0]
        if (progress.result.total > 0)
          progress.progress = prog[@status][0] + 
            prog[@status][1] * progress.result.servers.inject(0){|sum, vm| sum += vm.get_progress} / progress.result.total / 100
        end
      else
        progress.progress = 100
      end
      progress
    end

    def cluster_failed(task)
      @logger.debug("Enter Cluster_failed")
      task.set_finish("failed")
      @success = false
      @finished = true
    end

    def cluster_done(task)
      @logger.debug("Enter cluster_done")
      # TODO finish cluster information
      @status = CLUSTER_DONE
      task.set_finish("success")
      @success = true
      @finished = true
    end


  end
end

